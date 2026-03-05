#!/bin/bash
# =========================================================
# SinNombre v2.0 - SQUID (Proxy HTTP)
# Archivo: SN/Protocolos/squid.sh
#
# CAMBIOS v2.0 (2026-03-05):
# - Usa lib/colores.sh (sin colores duplicados)
# - Barra de progreso fina (━╸) + spinner profesional
# - Desinstalación real (purge + eliminar configs/ACLs/logs)
# - Función squid_restart() centralizada (no repetida 8 veces)
# - Función squid_conf() detecta squid/squid3 una sola vez
# - Corrección de errores, validaciones, ortografía
# - Menú con estado y puertos en header
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
  sep() { echo -e "${R}──────────────────────────────────────────────────────────${N}"; }
  pause(){ echo ""; read -r -p "Presiona Enter para continuar..."; }
fi

# ── Archivos de ACL ─────────────────────────────────────
HOSTS_DENY="/etc/dominio-denie"
REGEX_DENY="/etc/exprecion-denie"

# =========================================================
#  ANIMACIONES
# =========================================================

progress_bar() {
  local msg="$1"
  local duration="${2:-3}"
  local width=20
  tput civis # Ocultar cursor

  for ((i = 0; i <= width; i++)); do
    local pct=$(( i * 100 / width ))
    # Definir color según progreso
    local bar_color="$R"
    (( pct > 33 )) && bar_color="$Y"
    (( pct > 66 )) && bar_color="$G"

    # CONSEJO: Usamos \r al inicio y NO usamos \n al final
    printf "\r  ${C}•${N} ${W}%-20s${N} ${bar_color}" "$msg"
    
    for ((j = 0; j < i; j++)); do printf "━"; done
    (( i < width )) && printf "╸" || printf "━"

    printf "${D}"
    for ((j = i + 1; j < width; j++)); do printf "━"; done
    
    # El truco: %3d%% para mantener el ancho constante
    printf "${N} ${W}%3d%%${N}" "$pct"

    # Importante: sleep con valores pequeños para suavidad
    sleep "$(echo "scale=4; $duration / $width" | bc -l 2>/dev/null || echo "0.1")"
  done

  echo -e "  ${G}✓${N}" # Nueva línea solo al terminar
  tput cnorm # Mostrar cursor
}
spinner() {
  local pid="$1"
  local msg="${2:-Procesando...}"
  local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
  local i=0
  tput civis

  while kill -0 "$pid" 2>/dev/null; do
    # \e[K borra rastro de texto anterior
    printf "\r  ${C}${frames[$i]}${N} ${W}%s${N}\e[K" "$msg"
    i=$(( (i + 1) % ${#frames[@]} ))
    sleep 0.1
  done

  wait "$pid"
  local res=$?
  
  if [[ $res -eq 0 ]]; then
    printf "\r  ${G}✓${N} ${W}%-50s${N}\e[K\n" "$msg"
  else
    printf "\r  ${R}✗${N} ${W}%-50s${N}\e[K\n" "$msg"
  fi
  tput cnorm
}
# =========================================================
#  UTILIDADES
# =========================================================

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    hr
    echo -e "  ${R}✗${N} ${W}Ejecuta como root${N}"
    echo -e "  ${W}Usa:${N} ${C}sudo menu${N}  ${W}o${N}  ${C}sudo sn${N}"
    hr
    exit 1
  fi
}

# Detectar si squid está instalado y dónde está el config
squid_conf() {
  if [[ -e /etc/squid/squid.conf ]]; then
    echo "/etc/squid/squid.conf"
  elif [[ -e /etc/squid3/squid.conf ]]; then
    echo "/etc/squid3/squid.conf"
  else
    echo ""
  fi
}

squid_svc() {
  [[ -d /etc/squid ]] && echo "squid" || echo "squid3"
}

is_installed() {
  [[ -n "$(squid_conf)" ]]
}

is_running() {
  local svc
  svc="$(squid_svc)"
  systemctl is-active --quiet "$svc" 2>/dev/null
}

get_ports() {
  local conf
  conf="$(squid_conf)"
  [[ -z "$conf" ]] && return
  grep -w 'http_port' "$conf" 2>/dev/null | awk '{print $2}' | sort -n | tr '\n' ' ' | sed 's/ $//'
}

mportas() {
  ss -H -lnt 2>/dev/null | awk '{print $4}' | awk -F: '{print $NF}' | sort -n | uniq
}

fun_ip() {
  curl -fsS --max-time 2 ifconfig.me 2>/dev/null \
    || curl -fsS --max-time 2 https://api.ipify.org 2>/dev/null \
    || echo "127.0.0.1"
}

# Reiniciar squid (centralizado — se usa en todas las funciones)
squid_restart() {
  local svc
  svc="$(squid_svc)"
  (
    systemctl restart "$svc" >/dev/null 2>&1 \
      || service "$svc" restart >/dev/null 2>&1 \
      || /etc/init.d/"$svc" restart >/dev/null 2>&1 || true
    sleep 1
  ) &
  spinner $! "Reiniciando servicio ${svc}..."
}

# =========================================================
#  INSTALAR SQUID
# =========================================================
install_squid() {
  clear
  hr
  echo -e "${W}${BOLD}          INSTALADOR SQUID PROXY${N}"
  hr
  echo ""
  echo -e "  ${C}Ingrese los puertos separados por espacio${N}"
  echo -e "  ${D}Ejemplo: 80 8080 8799 3128${N}"
  sep

  local PORT=""
  while [[ -z "$PORT" ]]; do
    echo -ne "  ${W}Puertos: ${G}"
    read -r input_ports
    echo -ne "${N}"

    if [[ -z "${input_ports:-}" ]]; then
      echo -e "  ${R}✗${N} ${W}Debes ingresar al menos un puerto${N}"
      continue
    fi

    # Validar cada puerto
    local valid_ports="" invalid=false
    for p in $input_ports; do
      if [[ ! "$p" =~ ^[0-9]+$ ]] || (( p < 1 || p > 65535 )); then
        echo -e "  ${R}✗${N} ${W}Puerto ${Y}${p}${W} inválido${N}"
        invalid=true
      elif mportas | grep -qx "$p"; then
        echo -e "  ${R}✗${N} ${W}Puerto ${Y}${p}${W} ya está en uso${N}"
        invalid=true
      else
        echo -e "  ${G}✓${N} ${W}Puerto ${Y}${p}${W} disponible${N}"
        valid_ports="$valid_ports $p"
      fi
    done

    valid_ports="$(echo "$valid_ports" | xargs)"
    if [[ -z "$valid_ports" ]]; then
      echo -e "  ${R}✗${N} ${W}Ningún puerto válido${N}"
      echo ""
    else
      PORT="$valid_ports"
    fi
  done

  echo ""
  sep

  # Paso 1: Actualizar repos
  (
    apt-get update -y >/dev/null 2>&1 || true
  ) &
  spinner $! "Actualizando repositorios..."

  # Paso 2: Instalar squid
  progress_bar "Instalando Squid" 3
  apt-get install -y squid >/dev/null 2>&1 || apt-get install -y squid3 >/dev/null 2>&1 || {
    echo -e "  ${R}✗${N} ${W}Error al instalar Squid${N}"
    pause
    return
  }

  # Paso 3: Crear archivos ACL
  progress_bar "Creando ACLs" 1
  [[ ! -f "$HOSTS_DENY" ]] && echo ".ejemplo.com/" > "$HOSTS_DENY"
  [[ ! -f "$REGEX_DENY" ]] && echo "torrent" > "$REGEX_DENY"

  # Paso 4: Detectar config y escribir
  local conf
  conf="$(squid_conf)"
  if [[ -z "$conf" ]]; then
    echo -e "  ${R}✗${N} ${W}No se encontró squid.conf después de instalar${N}"
    pause
    return
  fi

  local ip
  ip="$(fun_ip)"

  progress_bar "Escribiendo configuración" 2
  cat > "$conf" <<EOF
# Configuración Squid - SinNombre v2.0
acl localhost src 127.0.0.1/32 ::1
acl to_localhost dst 127.0.0.0/8 0.0.0.0/32 ::1
acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 21
acl Safe_ports port 443
acl Safe_ports port 70
acl Safe_ports port 210
acl Safe_ports port 1025-65535
acl Safe_ports port 280
acl Safe_ports port 488
acl Safe_ports port 591
acl Safe_ports port 777
acl CONNECT method CONNECT
acl SSH dst ${ip}-${ip}/255.255.255.255
acl expresion-deny url_regex '${REGEX_DENY}'
acl dominio-deny dstdomain '${HOSTS_DENY}'
http_access deny expresion-deny
http_access deny dominio-deny
http_access allow SSH
http_access allow manager localhost
http_access deny manager
http_access allow localhost

# Puertos
EOF

  for pts in $PORT; do
    echo "http_port $pts" >> "$conf"
    [[ -f "/usr/sbin/ufw" ]] && ufw allow "$pts"/tcp >/dev/null 2>&1 || true
  done

  cat >> "$conf" <<EOF

http_access allow all
coredump_dir /var/spool/squid
refresh_pattern ^ftp: 1440 20% 10080
refresh_pattern ^gopher: 1440 0% 1440
refresh_pattern -i (/cgi-bin/|\?) 0 0% 0
refresh_pattern . 0 20% 4320

# Nombre visible
visible_hostname VPS-SN
EOF

  # Paso 5: Iniciar servicio
  local svc
  svc="$(squid_svc)"
  (
    systemctl enable "$svc" >/dev/null 2>&1 || true
    systemctl restart "$svc" >/dev/null 2>&1 || service "$svc" restart >/dev/null 2>&1 || true
    sleep 1
  ) &
  spinner $! "Iniciando servicio ${svc}..."

  echo ""
  hr
  echo -e "  ${G}${BOLD}✓ SQUID INSTALADO Y CONFIGURADO${N}"
  hr
  echo ""
  echo -e "  ${W}Puertos:${N}       ${Y}${PORT}${N}"
  echo -e "  ${W}IP servidor:${N}   ${C}${ip}${N}"
  echo -e "  ${W}Config:${N}        ${C}${conf}${N}"
  echo ""
  hr
  pause
}

# =========================================================
#  DESINSTALAR SQUID
# =========================================================
uninstall_squid() {
  clear
  hr
  echo -e "${W}${BOLD}          DESINSTALAR SQUID${N}"
  hr

  if ! is_installed; then
    echo -e "  ${Y}⚠${N} ${W}Squid no está instalado${N}"
    pause
    return
  fi

  echo ""
  echo -e "  ${Y}⚠ Se eliminará completamente:${N}"
  echo -e "    ${W}•${N} Paquete squid / squid3"
  echo -e "    ${W}•${N} Configuración ${C}/etc/squid/${N}"
  echo -e "    ${W}•${N} ACLs de dominios y expresiones"
  echo -e "    ${W}•${N} Logs y cache"
  echo ""
  echo -ne "  ${W}¿Estás seguro? (s/n): ${G}"
  read -r confirm
  echo -ne "${N}"
  [[ "${confirm,,}" == "s" ]] || { echo -e "  ${Y}Cancelado${N}"; pause; return; }

  echo ""
  sep

  # Paso 1: Detener servicios
  (
    systemctl stop squid >/dev/null 2>&1 || true
    systemctl stop squid3 >/dev/null 2>&1 || true
    systemctl disable squid >/dev/null 2>&1 || true
    systemctl disable squid3 >/dev/null 2>&1 || true
    sleep 0.5
  ) &
  spinner $! "Deteniendo servicios..."

  # Paso 2: Purgar paquetes
  progress_bar "Eliminando paquetes" 3
  apt-get purge -y squid squid3 squid-common >/dev/null 2>&1 || true
  apt-get autoremove -y >/dev/null 2>&1 || true

  # Paso 3: Eliminar configuración
  progress_bar "Limpiando configuración" 2
  rm -rf /etc/squid /etc/squid3 >/dev/null 2>&1 || true
  rm -f "$HOSTS_DENY" "$REGEX_DENY" >/dev/null 2>&1 || true

  # Paso 4: Limpiar logs y cache
  (
    rm -rf /var/log/squid /var/log/squid3 >/dev/null 2>&1 || true
    rm -rf /var/spool/squid /var/spool/squid3 >/dev/null 2>&1 || true
    systemctl daemon-reload >/dev/null 2>&1 || true
    sleep 0.3
  ) &
  spinner $! "Limpiando logs y cache..."

  echo ""
  hr
  echo -e "  ${G}${BOLD}✓ SQUID DESINSTALADO COMPLETAMENTE${N}"
  hr
  echo ""
  sleep 1
  pause
}

# =========================================================
#  AGREGAR PUERTOS
# =========================================================
add_port() {
  clear
  hr
  echo -e "${W}${BOLD}          AGREGAR PUERTOS SQUID${N}"
  hr

  local conf
  conf="$(squid_conf)"
  [[ -z "$conf" ]] && { echo -e "  ${R}✗${N} ${W}Squid no instalado${N}"; pause; return; }

  local current
  current="$(get_ports)"
  echo ""
  echo -e "  ${W}Puertos actuales:${N} ${Y}${current:-Ninguno}${N}"
  sep
  echo -e "  ${D}Ingrese nuevos puertos separados por espacio${N}"
  echo ""

  echo -ne "  ${W}Nuevos puertos: ${G}"
  read -r input_ports
  echo -ne "${N}"

  if [[ -z "${input_ports:-}" ]]; then
    echo -e "  ${Y}Cancelado${N}"
    pause
    return
  fi

  local new_ports=""
  for p in $input_ports; do
    if [[ ! "$p" =~ ^[0-9]+$ ]] || (( p < 1 || p > 65535 )); then
      echo -e "  ${R}✗${N} Puerto ${Y}${p}${N} inválido"
    elif mportas | grep -qx "$p"; then
      echo -e "  ${R}✗${N} Puerto ${Y}${p}${N} ya en uso"
    else
      echo -e "  ${G}✓${N} Puerto ${Y}${p}${N} OK"
      new_ports="$new_ports $p"
    fi
  done

  new_ports="$(echo "$new_ports" | xargs)"
  if [[ -z "$new_ports" ]]; then
    echo -e "  ${R}✗${N} ${W}Ningún puerto válido${N}"
    pause
    return
  fi

  echo ""
  progress_bar "Agregando puertos" 2

  # Insertar después del último http_port
  for p in $new_ports; do
    echo "http_port $p" >> "$conf"
    [[ -f "/usr/sbin/ufw" ]] && ufw allow "$p"/tcp >/dev/null 2>&1 || true
  done

  squid_restart

  echo ""
  hr
  echo -e "  ${G}${BOLD}✓ Puertos agregados: ${Y}${new_ports}${N}"
  hr
  pause
}

# =========================================================
#  QUITAR PUERTO
# =========================================================
del_port() {
  clear
  hr
  echo -e "${W}${BOLD}          QUITAR PUERTO SQUID${N}"
  hr

  local conf
  conf="$(squid_conf)"
  [[ -z "$conf" ]] && { echo -e "  ${R}✗${N} ${W}Squid no instalado${N}"; pause; return; }

  local ports_list
  ports_list="$(get_ports)"
  if [[ -z "${ports_list:-}" ]]; then
    echo -e "  ${Y}⚠${N} ${W}No hay puertos configurados${N}"
    pause
    return
  fi

  local -a port_arr=($ports_list)
  local count="${#port_arr[@]}"

  if [[ "$count" -lt 2 ]]; then
    echo ""
    echo -e "  ${Y}⚠${N} ${W}Solo hay un puerto (${port_arr[0]}). No se puede eliminar.${N}"
    echo -ne "  ${W}¿Desea detener el servicio? (s/n): ${G}"
    read -r a
    echo -ne "${N}"
    if [[ "${a,,}" == "s" ]]; then
      local svc
      svc="$(squid_svc)"
      (
        systemctl stop "$svc" >/dev/null 2>&1 || service "$svc" stop >/dev/null 2>&1 || true
        sleep 0.5
      ) &
      spinner $! "Deteniendo servicio..."
    fi
    pause
    return
  fi

  echo ""
  echo -e "  ${W}Seleccione el puerto a quitar:${N}"
  sep
  local n=1
  declare -A MAP=()
  for p in "${port_arr[@]}"; do
    echo -e "  ${G}[${W}${n}${G}]${N} ${W}▸${N} ${Y}${p}${N}"
    MAP["$n"]="$p"
    n=$((n + 1))
  done
  sep

  local opc=""
  while [[ -z "$opc" ]]; do
    echo -ne "  ${W}Opción: ${G}"
    read -r opc
    echo -ne "${N}"
    [[ "${opc:-}" =~ ^[0-9]+$ ]] || { echo -e "  ${R}Solo números${N}"; opc=""; continue; }
    [[ -n "${MAP[$opc]:-}" ]] || { echo -e "  ${R}Opción inválida${N}"; opc=""; continue; }
  done

  local target="${MAP[$opc]}"
  echo ""
  progress_bar "Eliminando puerto ${target}" 2
  sed -i "/^http_port ${target}$/d" "$conf" 2>/dev/null || true

  squid_restart

  echo ""
  hr
  echo -e "  ${G}${BOLD}✓ Puerto ${Y}${target}${G} eliminado${N}"
  hr
  pause
}

# =========================================================
#  BLOQUEAR HOST
# =========================================================
add_host() {
  clear
  hr
  echo -e "${W}${BOLD}          BLOQUEAR HOST${N}"
  hr

  # Mostrar hosts actuales
  if [[ -f "$HOSTS_DENY" ]]; then
    echo ""
    echo -e "  ${W}Hosts bloqueados actualmente:${N}"
    sep
    local n=1
    while read -r line; do
      [[ -z "${line:-}" ]] && continue
      local display="${line%/}"
      echo -e "    ${D}${n}.${N} ${C}${display}${N}"
      n=$((n + 1))
    done < "$HOSTS_DENY"
    sep
  fi

  echo ""
  echo -ne "  ${W}Nuevo host ${D}(ej: .facebook.com)${W}: ${G}"
  read -r new_host
  echo -ne "${N}"

  [[ -z "${new_host:-}" ]] && { echo -e "  ${Y}Cancelado${N}"; pause; return; }

  if [[ ! "$new_host" =~ ^\. ]]; then
    echo -e "  ${R}✗${N} ${W}El host debe comenzar con punto${N} ${D}(ej: .facebook.com)${N}"
    pause
    return
  fi

  local entry="${new_host}/"

  if grep -qF "$entry" "$HOSTS_DENY" 2>/dev/null; then
    echo -e "  ${Y}⚠${N} ${W}El host ya existe${N}"
    pause
    return
  fi

  echo "$entry" >> "$HOSTS_DENY"
  # Limpiar líneas vacías
  grep -v '^$' "$HOSTS_DENY" > /tmp/sn_hosts_tmp 2>/dev/null && mv /tmp/sn_hosts_tmp "$HOSTS_DENY"

  echo -e "  ${G}✓${N} ${W}Host ${C}${new_host}${W} bloqueado${N}"
  echo ""
  squid_restart
  pause
}

# =========================================================
#  DESBLOQUEAR HOST
# =========================================================
del_host() {
  clear
  hr
  echo -e "${W}${BOLD}          DESBLOQUEAR HOST${N}"
  hr

  if [[ ! -f "$HOSTS_DENY" ]] || [[ ! -s "$HOSTS_DENY" ]]; then
    echo -e "  ${Y}⚠${N} ${W}No hay hosts bloqueados${N}"
    pause
    return
  fi

  echo ""
  echo -e "  ${W}Hosts bloqueados:${N}"
  sep

  local n=1
  declare -A HOST_MAP=()
  while read -r line; do
    [[ -z "${line:-}" ]] && continue
    local display="${line%/}"
    echo -e "  ${G}[${W}${n}${G}]${N} ${W}▸${N} ${C}${display}${N}"
    HOST_MAP["$n"]="$line"
    n=$((n + 1))
  done < "$HOSTS_DENY"

  sep
  echo -e "  ${G}[${W}0${G}]${N}  ${W}Cancelar${N}"
  sep

  local opc=""
  while [[ -z "$opc" ]]; do
    echo -ne "  ${W}Opción: ${G}"
    read -r opc
    echo -ne "${N}"
    [[ "$opc" == "0" ]] && return
    [[ "${opc:-}" =~ ^[0-9]+$ ]] || { echo -e "  ${R}Solo números${N}"; opc=""; continue; }
    [[ -n "${HOST_MAP[$opc]:-}" ]] || { echo -e "  ${R}Opción inválida${N}"; opc=""; continue; }
  done

  local target="${HOST_MAP[$opc]}"
  grep -vF "$target" "$HOSTS_DENY" > /tmp/sn_hosts_tmp 2>/dev/null && mv /tmp/sn_hosts_tmp "$HOSTS_DENY"

  echo -e "  ${G}✓${N} ${W}Host ${C}${target%/}${W} desbloqueado${N}"
  echo ""
  squid_restart
  pause
}

# =========================================================
#  BLOQUEAR EXPRESIÓN REGULAR
# =========================================================
add_expre() {
  clear
  hr
  echo -e "${W}${BOLD}          BLOQUEAR EXPRESIÓN${N}"
  hr

  if [[ -f "$REGEX_DENY" ]]; then
    echo ""
    echo -e "  ${W}Expresiones bloqueadas actualmente:${N}"
    sep
    local n=1
    while read -r line; do
      [[ -z "${line:-}" ]] && continue
      echo -e "    ${D}${n}.${N} ${C}${line}${N}"
      n=$((n + 1))
    done < "$REGEX_DENY"
    sep
  fi

  echo ""
  echo -ne "  ${W}Nueva expresión ${D}(ej: torrent, casino)${W}: ${G}"
  read -r new_expr
  echo -ne "${N}"

  [[ -z "${new_expr:-}" ]] && { echo -e "  ${Y}Cancelado${N}"; pause; return; }

  if grep -qxF "$new_expr" "$REGEX_DENY" 2>/dev/null; then
    echo -e "  ${Y}⚠${N} ${W}La expresión ya existe${N}"
    pause
    return
  fi

  echo "$new_expr" >> "$REGEX_DENY"
  grep -v '^$' "$REGEX_DENY" > /tmp/sn_regex_tmp 2>/dev/null && mv /tmp/sn_regex_tmp "$REGEX_DENY"

  echo -e "  ${G}✓${N} ${W}Expresión ${C}${new_expr}${W} bloqueada${N}"
  echo ""
  squid_restart
  pause
}

# =========================================================
#  DESBLOQUEAR EXPRESIÓN REGULAR
# =========================================================
del_expre() {
  clear
  hr
  echo -e "${W}${BOLD}          DESBLOQUEAR EXPRESIÓN${N}"
  hr

  if [[ ! -f "$REGEX_DENY" ]] || [[ ! -s "$REGEX_DENY" ]]; then
    echo -e "  ${Y}⚠${N} ${W}No hay expresiones bloqueadas${N}"
    pause
    return
  fi

  echo ""
  echo -e "  ${W}Expresiones bloqueadas:${N}"
  sep

  local n=1
  declare -A EXPR_MAP=()
  while read -r line; do
    [[ -z "${line:-}" ]] && continue
    echo -e "  ${G}[${W}${n}${G}]${N} ${W}▸${N} ${C}${line}${N}"
    EXPR_MAP["$n"]="$line"
    n=$((n + 1))
  done < "$REGEX_DENY"

  sep
  echo -e "  ${G}[${W}0${G}]${N}  ${W}Cancelar${N}"
  sep

  local opc=""
  while [[ -z "$opc" ]]; do
    echo -ne "  ${W}Opción: ${G}"
    read -r opc
    echo -ne "${N}"
    [[ "$opc" == "0" ]] && return
    [[ "${opc:-}" =~ ^[0-9]+$ ]] || { echo -e "  ${R}Solo números${N}"; opc=""; continue; }
    [[ -n "${EXPR_MAP[$opc]:-}" ]] || { echo -e "  ${R}Opción inválida${N}"; opc=""; continue; }
  done

  local target="${EXPR_MAP[$opc]}"
  grep -vxF "$target" "$REGEX_DENY" > /tmp/sn_regex_tmp 2>/dev/null && mv /tmp/sn_regex_tmp "$REGEX_DENY"

  echo -e "  ${G}✓${N} ${W}Expresión ${C}${target}${W} desbloqueada${N}"
  echo ""
  squid_restart
  pause
}

# =========================================================
#  REINICIAR SERVICIO
# =========================================================
restart_menu() {
  clear
  hr
  squid_restart
  echo ""
  echo -e "  ${G}${BOLD}✓ Servicio Squid reiniciado${N}"
  hr
  pause
}

# =========================================================
#  MENÚ PRINCIPAL
# =========================================================
main_menu() {
  require_root

  # Si no está instalado, ir directo a instalar
  if ! is_installed; then
    install_squid
    # Si después de instalar sigue sin config, salir
    is_installed || return
  fi

  while true; do
    clear

    local ports st
    ports="$(get_ports)"

    if is_running; then
      st="${G}${BOLD}● ON${N}"
    else
      st="${R}${BOLD}● OFF${N}"
    fi

    hr
    echo -e "${W}${BOLD}              ADMINISTRADOR SQUID PROXY${N}"
    hr
    echo -e "  ${W}ESTADO:${N}    ${st}"
    echo -e "  ${W}PUERTOS:${N}   ${Y}${ports:-Ninguno}${N}"
    hr
    echo ""
    echo -e "  ${G}[${W}1${G}]${N}  ${C}Bloquear host${N}"
    echo -e "  ${G}[${W}2${G}]${N}  ${C}Desbloquear host${N}"
    sep
    echo -e "  ${G}[${W}3${G}]${N}  ${C}Bloquear expresión regular${N}"
    echo -e "  ${G}[${W}4${G}]${N}  ${C}Desbloquear expresión regular${N}"
    sep
    echo -e "  ${G}[${W}5${G}]${N}  ${C}Agregar puertos${N}"
    echo -e "  ${G}[${W}6${G}]${N}  ${C}Quitar puerto${N}"
    sep
    echo -e "  ${G}[${W}7${G}]${N}  ${C}Reiniciar servicio${N}"
    echo -e "  ${G}[${W}8${G}]${N}  ${R}Desinstalar Squid${N}"
    hr
    echo -e "  ${G}[${W}0${G}]${N}  ${W}Volver${N}"
    hr
    echo ""
    echo -ne "  ${W}Opción: ${G}"
    read -r opcion
    echo -ne "${N}"

    case "${opcion:-}" in
      1) add_host ;;
      2) del_host ;;
      3) add_expre ;;
      4) del_expre ;;
      5) add_port ;;
      6) del_port ;;
      7) restart_menu ;;
      8) uninstall_squid; is_installed || break ;;
      0) break ;;
      *) echo -e "  ${R}Opción inválida${N}"; sleep 1 ;;
    esac
  done
}

# ── Manejo de señales ───────────────────────────────────
trap 'echo -ne "${N}"; tput cnorm 2>/dev/null; exit 0' SIGINT SIGTERM

main_menu
