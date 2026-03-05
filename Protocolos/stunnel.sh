#!/bin/bash
set -euo pipefail

# =========================================================
# SinNombre v2.0 - STUNNEL (SSL) — Estilo SN-Manager
# Archivo: SN/Protocolos/stunnel.sh
#
# CAMBIOS v2.0 (2026-03-05):
# - Usa lib/colores.sh (sin colores duplicados)
# - Barra de progreso fina animada (━╸) estilo profesional
# - Spinner para procesos en background
# - Desinstalación real (purge + eliminar configs/certs/logs)
# - Corrección de errores en arrays, detección de puertos, sed
# - FIX SSL lento (MSS/MTU clamp) integrado
# =========================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── Cargar colores desde lib ────────────────────────────
LIB_COLORES="$ROOT_DIR/lib/colores.sh"
if [[ -f "$LIB_COLORES" ]]; then
  source "$LIB_COLORES"
else
  R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; B='\033[0;34m'
  C='\033[0;36m'; W='\033[1;37m'; N='\033[0m'; D='\033[2m'; BOLD='\033[1m'
  hr()  { echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"; }
  sep() { echo -e "${R}──────────────────────────���───────────────────────────────${N}"; }
  pause(){ echo ""; read -r -p "Presiona Enter para continuar..."; }
fi

# ── Rutas de configuración ──────────────────────────────
CONF="/etc/stunnel/stunnel.conf"
PEM="/etc/stunnel/stunnel.pem"
DEFAULTS="/etc/default/stunnel4"

# ── Variables globales ──────────────────────────────────
DPB=""
declare -a drop=()

# =========================================================
#  ANIMACIONES PROFESIONALES
# =========================================================

# Barra fina animada (━╸)
# Uso: progress_bar "Mensaje" [duración_segundos]
# Los colores cambian según el progreso:
#   0-33%  = Rojo (R)   -> algo peligroso/empezando
#   34-66% = Amarillo (Y) -> en progreso
#   67-100%= Verde (G)   -> casi listo
progress_bar() {
  local msg="$1"
  local duration="${2:-3}"
  local width=30

  tput civis 2>/dev/null || true

  for ((i = 0; i <= width; i++)); do
    local pct=$(( i * 100 / width ))

    # Color de la parte completada según progreso
    local bar_color="$R"
    (( pct > 33 )) && bar_color="$Y"
    (( pct > 66 )) && bar_color="$G"

    printf "\r  ${C}•${N} ${W}%-25s${N} " "$msg"

    # Parte completada
    printf "${bar_color}"
    for ((j = 0; j < i; j++)); do printf "━"; done

    # Cabeza de la barra (detalle estético)
    if (( i < width )); then
      printf "╸"
    else
      printf "━"
    fi

    # Parte restante (dim/gris)
    printf "${D}"
    for ((j = i + 1; j < width; j++)); do printf "━"; done

    printf "${N} ${W}%3d%%${N}" "$pct"

    sleep "$(echo "scale=4; $duration / $width" | bc 2>/dev/null || echo "0.08")"
  done

  echo -e "  ${G}✓${N}"
  tput cnorm 2>/dev/null || true
}

# Spinner para procesos en background
# Uso: comando_largo & spinner $! "Mensaje"
spinner() {
  local pid="$1"
  local msg="${2:-Procesando...}"
  local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
  local i=0

  tput civis 2>/dev/null || true

  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  ${C}${frames[$i]}${N} ${W}%s${N}" "$msg"
    i=$(( (i + 1) % ${#frames[@]} ))
    sleep 0.1
  done

  wait "$pid" 2>/dev/null
  local exit_code=$?

  if [[ $exit_code -eq 0 ]]; then
    printf "\r  ${G}✓${N} ${W}%-50s${N}\n" "$msg"
  else
    printf "\r  ${R}✗${N} ${W}%-50s${N}\n" "$msg"
  fi

  tput cnorm 2>/dev/null || true
  return $exit_code
}

# =========================================================
#  UTILIDADES DE STUNNEL
# =========================================================

mportas() {
  ss -H -lnt 2>/dev/null | awk '{print $4}' | awk -F: '{print $NF}' | sort -n | uniq
}

is_installed() {
  dpkg -l 2>/dev/null | grep -qE '^[hi]i[[:space:]]+stunnel4'
}

is_on() {
  systemctl is-active --quiet stunnel4 2>/dev/null && return 0
  service stunnel4 status 2>/dev/null | grep -qi "active" && return 0
  return 1
}

show_ports() {
  local ports
  ports="$(ss -H -lntp 2>/dev/null | awk '$0 ~ /(stunnel|stunnel4)/ {print $4}' \
    | awk -F: '{print $NF}' | sort -n | uniq | tr '\n' ' ' | sed 's/[[:space:]]\+$//' || true)"
  [[ -n "${ports:-}" ]] && echo "$ports" || echo "Ninguno"
}

drop_port() {
  DPB=""
  local portasVAR
  portasVAR="$(lsof -V -i tcp -P -n 2>/dev/null | grep -v "ESTABLISHED" | grep -v "COMMAND" | grep "LISTEN" || true)"
  local NOREPEAT=""
  local reQ Port

  while read -r port; do
    [[ -z "${port:-}" ]] && continue
    reQ="$(echo "${port}" | awk '{print $1}')"
    Port="$(echo "${port}" | awk '{print $9}' | awk -F ":" '{print $2}')"
    [[ -z "${Port:-}" ]] && continue

    echo -e "$NOREPEAT" | grep -qw "$Port" && continue
    NOREPEAT+="$Port\n"

    case "${reQ}" in
      cupsd|systemd-r|stunnel4|stunnel) continue ;;
      *) DPB+=" ${reQ}:${Port}" ;;
    esac
  done <<< "${portasVAR}"
}

ensure_enabled() {
  [[ -f "$DEFAULTS" ]] || return 0
  if grep -q '^ENABLED=' "$DEFAULTS"; then
    sed -i 's/^ENABLED=.*/ENABLED=1/' "$DEFAULTS" 2>/dev/null || true
  else
    echo "ENABLED=1" >> "$DEFAULTS"
  fi
  systemctl enable stunnel4 >/dev/null 2>&1 || true
}

gen_pem() {
  mkdir -p /etc/stunnel >/dev/null 2>&1 || true

  local tmp="/tmp/sn_stunnel.$$"
  mkdir -p "$tmp"

  (
    openssl genrsa -out "$tmp/stunnel.key" 2048 >/dev/null 2>&1
    openssl req -new -key "$tmp/stunnel.key" -x509 -days 1000 \
      -out "$tmp/stunnel.crt" \
      -subj "/C=US/ST=State/L=City/O=SinNombre/CN=localhost" >/dev/null 2>&1
    cat "$tmp/stunnel.key" "$tmp/stunnel.crt" > "$PEM"
    chmod 600 "$PEM" >/dev/null 2>&1 || true
  ) &
  spinner $! "Generando certificado SSL (2048 bits)..."
  local gen_ok=$?

  if [[ $gen_ok -eq 0 ]] && openssl x509 -in "$PEM" -text >/dev/null 2>&1; then
    rm -rf "$tmp" >/dev/null 2>&1 || true
    return 0
  else
    rm -rf "$tmp" "$PEM" >/dev/null 2>&1 || true
    echo -e "  ${R}✗${N} ${W}Error al generar certificado${N}"
    return 1
  fi
}

choose_cert() {
  local db
  db="$(ls /etc/SN/cert 2>/dev/null || true)"
  if [[ -n "$db" ]] && echo "$db" | grep -q ".crt"; then
    local cert key
    cert="$(echo "$db" | grep ".crt" | head -1)"
    key="$(echo "$db" | grep ".key" | head -1)"
    echo ""
    sep
    echo -e "  ${Y}${BOLD}CERTIFICADO SSL ENCONTRADO${N}"
    echo -e "  ${C}CERT:${N} ${Y}${cert}${N}"
    echo -e "  ${C}KEY:${N}  ${Y}${key}${N}"
    sep
    echo -ne "  ${W}¿Usar este certificado? [s/n]: ${G}"
    read -r opcion
    echo -ne "${N}"
    if [[ "${opcion,,}" == "s" ]]; then
      cp "/etc/SN/cert/$cert" /tmp/stunnel.crt 2>/dev/null || true
      cp "/etc/SN/cert/$key" /tmp/stunnel.key 2>/dev/null || true
      cat /tmp/stunnel.key /tmp/stunnel.crt > "$PEM"
      chmod 600 "$PEM"
      rm -f /tmp/stunnel.crt /tmp/stunnel.key
      echo -e "  ${G}✓${N} ${W}Usando certificado existente${N}"
      return
    fi
  fi
  gen_pem
}

service_restart() {
  ensure_enabled
  service stunnel4 restart >/dev/null 2>&1 || systemctl restart stunnel4 >/dev/null 2>&1 || true
}

service_stop() {
  service stunnel4 stop >/dev/null 2>&1 || systemctl stop stunnel4 >/dev/null 2>&1 || true
}

service_start() {
  ensure_enabled
  service stunnel4 start >/dev/null 2>&1 || systemctl start stunnel4 >/dev/null 2>&1 || true
}

service_is_inactive() {
  systemctl is-active --quiet stunnel4 2>/dev/null && return 1
  return 0
}

# =========================================================
#  FIX SSL LENTO (MTU/MSS clamp)
# =========================================================

mss_fix_is_applied() {
  iptables -t mangle -C POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu >/dev/null 2>&1
}

mss_fix_apply() {
  if mss_fix_is_applied; then
    echo -e "  ${Y}⚠${N} ${W}MSS clamp ya estaba aplicado${N}"
    return 0
  fi
  iptables -t mangle -A POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
  echo -e "  ${G}✓${N} ${W}MSS clamp aplicado (POSTROUTING TCP SYN)${N}"
}

mss_fix_persist() {
  if command -v netfilter-persistent >/dev/null 2>&1; then
    netfilter-persistent save >/dev/null 2>&1 || true
    echo -e "  ${G}✓${N} ${W}Reglas guardadas (netfilter-persistent)${N}"
    return 0
  fi

  if command -v apt-get >/dev/null 2>&1; then
    (
      apt-get update -y >/dev/null 2>&1 || true
      DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent >/dev/null 2>&1 || true
    ) &
    spinner $! "Instalando iptables-persistent..."

    if command -v netfilter-persistent >/dev/null 2>&1; then
      netfilter-persistent save >/dev/null 2>&1 || true
      echo -e "  ${G}✓${N} ${W}Reglas guardadas (iptables-persistent)${N}"
      return 0
    fi
  fi

  echo -e "  ${Y}⚠${N} ${W}No se pudo persistir automáticamente${N}"
  echo -e "  ${D}Aplicado en runtime; tras reinicio podría perderse${N}"
  return 0
}

ask_apply_ssl_fix() {
  is_on || return 0

  echo ""
  sep
  echo -e "  ${W}${BOLD}FIX opcional para SSL lento:${N} ${C}clamp MSS a PMTU${N}"
  echo -e "  ${D}Ayuda a evitar fragmentación (común en túneles SSL/TLS)${N}"

  if mss_fix_is_applied; then
    echo -e "  ${G}Estado actual:${N} ${Y}Ya aplicado ✓${N}"
    sep
    return 0
  fi

  echo -ne "  ${W}¿Aplicar fix recomendado ahora? (s/n): ${G}"
  read -r yn
  echo -ne "${N}"
  if [[ "${yn,,}" == "s" ]]; then
    mss_fix_apply
    echo -ne "  ${W}¿Hacerlo persistente tras reinicio? (s/n): ${G}"
    read -r yn2
    echo -ne "${N}"
    [[ "${yn2,,}" == "s" ]] && mss_fix_persist
  fi
  sep
}

# =========================================================
#  INSTALAR STUNNEL
# =========================================================
ssl_stunel() {
  if is_installed; then
    # ── DESINSTALAR ──────────────────────────────────────
    clear
    hr
    echo -e "${W}${BOLD}          DESINSTALAR STUNNEL SSL${N}"
    hr
    echo ""
    echo -e "  ${Y}⚠ Se eliminará completamente:${N}"
    echo -e "    ${W}•${N} Paquete stunnel4"
    echo -e "    ${W}•${N} Configuración ${C}/etc/stunnel/${N}"
    echo -e "    ${W}•${N} Certificados SSL generados"
    echo -e "    ${W}•${N} Defaults y logs"
    echo ""
    echo -ne "  ${W}¿Estás seguro? (s/n): ${G}"
    read -r confirm
    echo -ne "${N}"
    [[ "${confirm,,}" == "s" ]] || { echo -e "  ${Y}Cancelado${N}"; pause; return; }

    echo ""
    sep

    # Paso 1: Detener servicio
    (
      service_stop
      systemctl disable stunnel4 >/dev/null 2>&1 || true
      sleep 0.5
    ) &
    spinner $! "Deteniendo servicio stunnel4..."

    # Paso 2: Purgar paquete
    progress_bar "Eliminando paquete" 3
    apt-get purge -y stunnel4 >/dev/null 2>&1 || true
    apt-get autoremove -y >/dev/null 2>&1 || true

    # Paso 3: Eliminar archivos de configuración
    progress_bar "Limpiando configuración" 2
    rm -rf /etc/stunnel >/dev/null 2>&1 || true
    rm -f /etc/default/stunnel4 >/dev/null 2>&1 || true

    # Paso 4: Limpiar logs y restos
    (
      rm -f /var/log/stunnel4.log >/dev/null 2>&1 || true
      rm -f /var/log/stunnel4/*.log >/dev/null 2>&1 || true
      rm -rf /var/log/stunnel4 >/dev/null 2>&1 || true
      systemctl daemon-reload >/dev/null 2>&1 || true
      sleep 0.3
    ) &
    spinner $! "Limpiando logs y restos..."

    echo ""
    hr
    echo -e "  ${G}${BOLD}✓ STUNNEL DESINSTALADO COMPLETAMENTE${N}"
    hr
    echo ""
    sleep 1
    pause
    return
  fi

  # ── INSTALAR ────────────────────────────────────────
  clear
  hr
  echo -e "${W}${BOLD}          INSTALADOR SSL By SinNombre${N}"
  hr
  echo ""
  echo -e "  ${C}Seleccione puerto de redirección de tráfico${N}"
  sep

  # Preparar dependencias en background
  (
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y lsof >/dev/null 2>&1 || true
  ) &
  spinner $! "Preparando dependencias..."

  drop_port
  local n=1 num_opc=0
  drop=()

  echo ""
  for i in $DPB; do
    local proto proto2 port
    proto="$(echo "$i" | awk -F ":" '{print $1}')"
    proto2="$(printf '%-12s' "$proto")"
    port="$(echo "$i" | awk -F ":" '{print $2}')"
    echo -e "  ${G}[${W}${n}${G}]${N} ${W}▸${N} ${C}${proto2}${N}${Y}${port}${N}"
    drop[$n]="$port"
    num_opc="$n"
    n=$((n + 1))
  done

  sep

  if [[ "$num_opc" -lt 1 ]]; then
    echo -e "  ${R}✗${N} ${W}No hay puertos disponibles para redirigir${N}"
    pause
    return
  fi

  local opc=""
  while [[ -z "${opc:-}" ]]; do
    echo -ne "  ${W}Opción: ${G}"
    read -r opc
    echo -ne "${N}"
    [[ "${opc:-}" =~ ^[0-9]+$ ]] || { echo -e "  ${R}Solo números${N}"; opc=""; continue; }
    [[ -n "${drop[$opc]:-}" ]] || { echo -e "  ${R}Opción inválida${N}"; opc=""; continue; }
  done

  echo ""
  hr
  echo -e "  ${W}Puerto de redirección:${N} ${Y}${drop[$opc]}${N}"
  hr

  local opc2=""
  while [[ -z "${opc2:-}" ]]; do
    echo -ne "  ${W}Ingrese un puerto para SSL: ${G}"
    read -r opc2
    echo -ne "${N}"
    [[ "${opc2:-}" =~ ^[0-9]+$ ]] || { echo -e "  ${R}Puerto inválido${N}"; opc2=""; continue; }
    if mportas | grep -qx "${opc2}"; then
      echo -e "  ${R}✗${N} ${W}Puerto ${Y}${opc2}${W} ya está en uso${N}"
      opc2=""
      continue
    fi
    echo -e "  ${G}✓${N} ${W}Puerto SSL ${Y}${opc2}${W} disponible${N}"
  done

  echo ""
  sep

  # Elegir certificado
  choose_cert

  echo ""
  sep

  # Instalar stunnel4 con barra de progreso
  progress_bar "Descargando stunnel4" 3
  apt-get install -y stunnel4 openssl >/dev/null 2>&1 || true

  progress_bar "Configurando servicio" 2
  systemctl daemon-reload >/dev/null 2>&1 || true
  ensure_enabled

  # Escribir configuración
  progress_bar "Escribiendo config SSL" 1
  cat > "$CONF" <<EOF
client = no
[SSL]
cert = ${PEM}
accept = ${opc2}
connect = 127.0.0.1:${drop[$opc]}
EOF

  # Iniciar servicio
  (
    service_restart
    sleep 0.5
  ) &
  spinner $! "Iniciando servicio stunnel4..."

  echo ""
  hr
  echo -e "  ${G}${BOLD}✓ INSTALADO CON ÉXITO${N}"
  hr
  echo ""
  echo -e "  ${W}Puerto SSL:${N}        ${G}${opc2}${N}"
  echo -e "  ${W}Redirección a:${N}     ${Y}${drop[$opc]}${N}"
  echo -e "  ${W}Certificado:${N}       ${C}${PEM}${N}"
  echo -e "  ${W}Configuración:${N}     ${C}${CONF}${N}"
  echo ""
  hr

  ask_apply_ssl_fix
  pause
}

# =========================================================
#  AGREGAR PUERTO SSL
# =========================================================
add_port() {
  clear
  hr
  echo -e "${W}${BOLD}          AGREGAR PUERTOS SSL${N}"
  hr

  if ! is_installed; then
    echo -e "  ${R}✗${N} ${W}Stunnel no está instalado${N}"
    pause
    return
  fi

  echo ""
  echo -e "  ${C}Seleccione puerto de redirección:${N}"
  sep

  drop_port
  local n=1 num_opc=0
  drop=()

  for i in $DPB; do
    local proto proto2 port
    proto="$(echo "$i" | awk -F ":" '{print $1}')"
    proto2="$(printf '%-12s' "$proto")"
    port="$(echo "$i" | awk -F ":" '{print $2}')"
    echo -e "  ${G}[${W}${n}${G}]${N} ${W}▸${N} ${C}${proto2}${N}${Y}${port}${N}"
    drop[$n]="$port"
    num_opc="$n"
    n=$((n + 1))
  done
  sep

  if [[ "$num_opc" -lt 1 ]]; then
    echo -e "  ${R}✗${N} ${W}No hay puertos disponibles${N}"
    pause
    return
  fi

  local opc=""
  while [[ -z "${opc:-}" ]]; do
    echo -ne "  ${W}Opción: ${G}"
    read -r opc
    echo -ne "${N}"
    [[ "${opc:-}" =~ ^[0-9]+$ ]] || { echo -e "  ${R}Solo números${N}"; opc=""; continue; }
    [[ -n "${drop[$opc]:-}" ]] || { echo -e "  ${R}Opción inválida${N}"; opc=""; continue; }
  done

  echo -e "  ${W}Puerto de redirección:${N} ${Y}${drop[$opc]}${N}"
  sep

  local opc2=""
  while [[ -z "${opc2:-}" ]]; do
    echo -ne "  ${W}Ingrese un puerto para SSL: ${G}"
    read -r opc2
    echo -ne "${N}"
    [[ "${opc2:-}" =~ ^[0-9]+$ ]] || { echo -e "  ${R}Puerto inválido${N}"; opc2=""; continue; }
    if mportas | grep -qx "${opc2}"; then
      echo -e "  ${R}✗${N} ${W}Puerto ${Y}${opc2}${W} ya en uso${N}"
      opc2=""
      continue
    fi
    echo -e "  ${G}✓${N} ${W}Puerto SSL ${Y}${opc2}${W} disponible${N}"
  done

  echo ""

  # Regenerar PEM si no existe
  if [[ ! -f "$PEM" ]]; then
    gen_pem
  fi

  progress_bar "Agregando puerto SSL" 2

  cat >> "$CONF" <<EOF

[SSL+]
cert = ${PEM}
accept = ${opc2}
connect = 127.0.0.1:${drop[$opc]}
EOF

  (
    service_restart
    sleep 0.5
  ) &
  spinner $! "Reiniciando servicio..."

  echo ""
  hr
  echo -e "  ${G}${BOLD}✓ PUERTO AGREGADO CON ÉXITO${N}"
  hr
  echo ""
  echo -e "  ${W}Nuevo puerto SSL:${N}  ${G}${opc2}${N}"
  echo -e "  ${W}Redirección a:${N}     ${Y}${drop[$opc]}${N}"
  echo ""
  hr

  ask_apply_ssl_fix
  pause
}

# =========================================================
#  INICIAR / PARAR SERVICIO
# =========================================================
start_stop() {
  clear
  hr

  if service_is_inactive; then
    (
      service_start
      sleep 0.5
    ) &
    spinner $! "Iniciando servicio stunnel4..."

    if is_on; then
      echo -e "  ${G}${BOLD}✓ Servicio stunnel4 iniciado${N}"
      ask_apply_ssl_fix
    else
      echo -e "  ${R}✗ Falla al iniciar servicio stunnel4${N}"
    fi
  else
    (
      service_stop
      sleep 0.5
    ) &
    spinner $! "Deteniendo servicio stunnel4..."

    if service_is_inactive; then
      echo -e "  ${Y}■ Servicio stunnel4 detenido${N}"
    else
      echo -e "  ${R}✗ Falla al detener servicio stunnel4${N}"
    fi
  fi

  hr
  pause
}

# =========================================================
#  QUITAR PUERTO SSL
# =========================================================
del_port() {
  clear
  hr
  echo -e "${W}${BOLD}          QUITAR PUERTOS SSL${N}"
  hr

  if ! is_installed; then
    echo -e "  ${R}✗${N} ${W}Stunnel no está instalado${N}"
    pause
    return
  fi

  local sslport
  sslport="$(lsof -V -i tcp -P -n 2>/dev/null \
    | grep -v "ESTABLISHED" | grep -v "COMMAND" \
    | grep "LISTEN" | grep -E 'stunnel|stunnel4' || true)"

  if [[ -z "${sslport:-}" ]]; then
    echo -e "  ${Y}⚠${N} ${W}No hay puertos SSL activos${N}"
    pause
    return
  fi

  local line_count
  line_count="$(echo "$sslport" | wc -l)"

  if [[ "$line_count" -lt 2 ]]; then
    echo -e "  ${Y}⚠${N} ${W}Solo hay un puerto SSL configurado${N}"
    echo -ne "  ${W}¿Desea detener el servicio? (s/n): ${G}"
    read -r a
    echo -ne "${N}"
    [[ "${a,,}" == "s" ]] && {
      (service_stop; sleep 0.3) &
      spinner $! "Deteniendo servicio..."
    }
    pause
    return
  fi

  echo ""
  echo -e "  ${W}Seleccione el puerto a quitar:${N}"
  sep
  local n=1
  drop=()
  while read -r i; do
    [[ -z "${i:-}" ]] && continue
    local port
    port="$(echo "$i" | awk '{print $9}' | cut -d ':' -f2)"
    [[ -z "${port:-}" ]] && continue
    echo -e "  ${G}[${W}${n}${G}]${N} ${W}▸${N} ${Y}${port}${N}"
    drop[$n]="$port"
    n=$((n + 1))
  done <<< "$sslport"
  sep

  local opc=""
  while [[ -z "${opc:-}" ]]; do
    echo -ne "  ${W}Opción: ${G}"
    read -r opc
    echo -ne "${N}"
    [[ "${opc:-}" =~ ^[0-9]+$ ]] || { echo -e "  ${R}Solo números${N}"; opc=""; continue; }
    [[ -n "${drop[$opc]:-}" ]] || { echo -e "  ${R}Opción inválida${N}"; opc=""; continue; }
  done

  echo ""
  progress_bar "Eliminando puerto ${drop[$opc]}" 2

  local match_line
  match_line="$(grep -n "accept = ${drop[$opc]}" "$CONF" 2>/dev/null | head -n1 | cut -d ':' -f1)"

  if [[ -n "${match_line:-}" && "${match_line:-0}" -gt 0 ]]; then
    local in=$(( match_line - 3 ))
    local en=$(( in + 4 ))
    (( in < 1 )) && in=1
    sed -i "${in},${en}d" "$CONF" 2>/dev/null || true
    # Renombrar [SSL+] a [SSL] si quedó como primera sección
    sed -i '0,/\[SSL+\]/s/\[SSL+\]/[SSL]/' "$CONF" 2>/dev/null || true
  fi

  (
    service_restart
    sleep 0.5
  ) &
  spinner $! "Reiniciando servicio..."

  ask_apply_ssl_fix

  echo ""
  hr
  echo -e "  ${G}${BOLD}✓ Puerto SSL ${Y}${drop[$opc]}${G} eliminado${N}"
  hr
  pause
}

# =========================================================
#  EDITAR REDIRECCIÓN
# =========================================================
edit_port() {
  clear
  hr
  echo -e "${W}${BOLD}      EDITAR PUERTO DE REDIRECCIÓN${N}"
  hr

  if ! is_installed; then
    echo -e "  ${R}✗${N} ${W}Stunnel no está instalado${N}"
    pause
    return
  fi

  local sslport
  sslport="$(lsof -V -i tcp -P -n 2>/dev/null \
    | grep -v "ESTABLISHED" | grep -v "COMMAND" \
    | grep "LISTEN" | grep -E 'stunnel|stunnel4' || true)"

  if [[ -z "${sslport:-}" ]]; then
    echo -e "  ${Y}⚠${N} ${W}No hay puertos SSL activos${N}"
    pause
    return
  fi

  echo ""
  echo -e "  ${W}Seleccione el puerto SSL a editar:${N}"
  sep
  local n=1
  drop=()
  while read -r i; do
    [[ -z "${i:-}" ]] && continue
    local port
    port="$(echo "$i" | awk '{print $9}' | cut -d ':' -f2)"
    [[ -z "${port:-}" ]] && continue
    echo -e "  ${G}[${W}${n}${G}]${N} ${W}▸${N} ${Y}${port}${N}"
    drop[$n]="$port"
    n=$((n + 1))
  done <<< "$sslport"
  sep

  local opc=""
  while [[ -z "${opc:-}" ]]; do
    echo -ne "  ${W}Opción: ${G}"
    read -r opc
    echo -ne "${N}"
    [[ "${opc:-}" =~ ^[0-9]+$ ]] || { echo -e "  ${R}Solo números${N}"; opc=""; continue; }
    [[ -n "${drop[$opc]:-}" ]] || { echo -e "  ${R}Opción inválida${N}"; opc=""; continue; }
  done

  local match_line
  match_line="$(grep -n "accept = ${drop[$opc]}" "$CONF" 2>/dev/null | head -n1 | cut -d ':' -f1)"

  if [[ -z "${match_line:-}" || "${match_line:-0}" -lt 1 ]]; then
    echo -e "  ${R}✗${N} ${W}No se encontró la entrada en la configuración${N}"
    pause
    return
  fi

  local in=$(( match_line + 1 ))
  local en
  en="$(sed -n "${in}p" "$CONF" 2>/dev/null | cut -d ':' -f2 | tr -d ' ')"

  echo ""
  echo -e "  ${W}Actual:${N} ${Y}${drop[$opc]}${W} ━━▸ ${C}${en}${N}"
  sep
  echo -e "  ${W}Seleccione nuevo destino:${N}"
  sep

  drop_port
  n=1
  drop=()
  for i in $DPB; do
    local port2 proto proto2
    port2="$(echo "$i" | awk -F ":" '{print $2}')"
    [[ "$port2" == "$en" ]] && continue
    proto="$(echo "$i" | awk -F ":" '{print $1}')"
    proto2="$(printf '%-12s' "$proto")"
    echo -e "  ${G}[${W}${n}${G}]${N} ${W}▸${N} ${C}${proto2}${N}${Y}${port2}${N}"
    drop[$n]="$port2"
    n=$((n + 1))
  done
  sep

  opc=""
  while [[ -z "${opc:-}" ]]; do
    echo -ne "  ${W}Opción: ${G}"
    read -r opc
    echo -ne "${N}"
    [[ "${opc:-}" =~ ^[0-9]+$ ]] || { echo -e "  ${R}Solo números${N}"; opc=""; continue; }
    [[ -n "${drop[$opc]:-}" ]] || { echo -e "  ${R}Opción inválida${N}"; opc=""; continue; }
  done

  echo ""
  progress_bar "Actualizando redirección" 2

  sed -i "${in}s/${en}/${drop[$opc]}/" "$CONF" 2>/dev/null || true

  (
    service_restart
    sleep 0.5
  ) &
  spinner $! "Reiniciando servicio..."

  ask_apply_ssl_fix

  echo ""
  hr
  echo -e "  ${G}${BOLD}✓ Redirección modificada${N}"
  hr
  pause
}

# =========================================================
#  REINICIAR SERVICIO
# =========================================================
restart_srv() {
  clear
  hr

  (
    service_restart
    sleep 0.5
  ) &
  spinner $! "Reiniciando servicio stunnel4..."

  echo -e "  ${G}${BOLD}✓ Servicio stunnel4 reiniciado${N}"
  hr

  ask_apply_ssl_fix
  pause
}

# =========================================================
#  EDITAR MANUAL (NANO)
# =========================================================
edit_nano() {
  if [[ ! -f "$CONF" ]]; then
    echo -e "  ${R}✗${N} ${W}No existe ${C}${CONF}${N}"
    pause
    return
  fi
  nano "$CONF"
  restart_srv
}

# =========================================================
#  MENÚ PRINCIPAL STUNNEL
# =========================================================
main_menu() {
  require_root

  while true; do
    clear
    local st ports mss

    if is_on; then
      st="${G}${BOLD}● ON${N}"
    else
      st="${R}${BOLD}● OFF${N}"
    fi

    ports="$(show_ports)"

    if mss_fix_is_applied; then
      mss="${G}MSS-FIX: ON ✓${N}"
    else
      mss="${R}MSS-FIX: OFF${N}"
    fi

    hr
    echo -e "${W}${BOLD}            ADMINISTRADOR STUNNEL SSL${N}"
    hr
    echo -e "  ${W}PUERTOS:${N}  ${Y}${ports}${N}"
    echo -e "  ${W}ESTADO:${N}   ${st}     ${mss}"
    hr

    echo -e "  ${G}[${W}1${G}]${N}  ${C}INSTALAR / DESINSTALAR${N}"

    if is_on; then
      sep
      echo -e "  ${G}[${W}2${G}]${N}  ${C}AGREGAR PUERTOS SSL${N}"
      echo -e "  ${G}[${W}3${G}]${N}  ${C}QUITAR PUERTOS SSL${N}"
      sep
      echo -e "  ${G}[${W}4${G}]${N}  ${C}EDITAR PUERTO DE REDIRECCIÓN${N}"
      echo -e "  ${G}[${W}5${G}]${N}  ${C}EDITAR MANUAL (NANO)${N}"
      sep
      echo -e "  ${G}[${W}6${G}]${N}  ${C}INICIAR/PARAR SERVICIO${N}  ${st}"
      echo -e "  ${G}[${W}7${G}]${N}  ${C}REINICIAR SERVICIO${N}"
      echo -e "  ${G}[${W}8${G}]${N}  ${C}APLICAR FIX SSL LENTO (MSS/MTU)${N}  ${mss}"
    else
      sep
      echo -e "  ${G}[${W}6${G}]${N}  ${C}INICIAR/PARAR SERVICIO${N}  ${st}"
    fi

    hr
    echo -e "  ${G}[${W}0${G}]${N}  ${W}VOLVER${N}"
    hr

    echo ""
    echo -ne "  ${W}Ingresa una opción: ${G}"
    read -r op
    echo -ne "${N}"

    case "${op:-}" in
      1) ssl_stunel ;;
      2) is_on && add_port     || { echo -e "  ${R}Servicio no está corriendo${N}"; sleep 1; } ;;
      3) is_on && del_port     || { echo -e "  ${R}Servicio no está corriendo${N}"; sleep 1; } ;;
      4) is_on && edit_port    || { echo -e "  ${R}Servicio no está corriendo${N}"; sleep 1; } ;;
      5) is_on && edit_nano    || { echo -e "  ${R}Servicio no está corriendo${N}"; sleep 1; } ;;
      6) start_stop ;;
      7) is_on && restart_srv  || { echo -e "  ${R}Servicio no está corriendo${N}"; sleep 1; } ;;
      8) is_on && ask_apply_ssl_fix || { echo -e "  ${R}Servicio no está corriendo${N}"; sleep 1; } ;;
      0) break ;;
      *) echo -e "  ${R}Opción inválida${N}"; sleep 1 ;;
    esac
  done
}

main_menu
