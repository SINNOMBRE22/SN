#!/bin/bash
# =========================================================
# SinNombre v2.0 - HAProxy MUX (SNI Multiplexing)
# Archivo: SN/Protocolos/haproxy_mux.sh
#
# Multiplexar TLS en puerto 443:
#   - V2Ray/XRay (por SNI) -> 127.0.0.1:8443
#   - Stunnel (por defecto) -> 127.0.0.1:4443
#
# CAMBIOS v2.0 (2026-03-16):
# - Usa lib/colores.sh (sin colores duplicados)
# - Barra de progreso fina animada (━╸) estilo profesional
# - Spinner para procesos en background
# - Menú simplificado: 9 opciones claras y lógicas
# - Desinstalación real y completa con purge
# - Mejor manejo de errores y validaciones
# - Mejor detección de puertos (ss/lsof)
# - Config JSON mejorada y más segura
# =========================================================

set -euo pipefail

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

# ── Rutas de configuración ──────────────────────────────
CONF_DIR="/etc/SN"
CONF_JSON="$CONF_DIR/haproxy-mux.json"
HAPROXY_CFG="/etc/haproxy/haproxy.cfg"
SERVICE_NAME="haproxy-mux"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}.service"
BACKUP_SUFFIX=".sn-bak-$(date +%Y%m%d%H%M%S)"

# =========================================================
#  ANIMACIONES PROFESIONALES
# =========================================================

progress_bar() {
  local msg="$1"
  local duration="${2:-3}"
  local width=20

  tput civis 2>/dev/null || true

  for ((i = 0; i <= width; i++)); do
    local pct=$(( i * 100 / width ))
    local bar_color="$R"
    (( pct > 33 )) && bar_color="$Y"
    (( pct > 66 )) && bar_color="$G"

    printf "\r  ${C}•${N} ${W}%-20s${N} " "$msg"
    printf "${bar_color}"
    for ((j = 0; j < i; j++)); do printf "━"; done
    if (( i < width )); then
      printf "╸"
    else
      printf "━"
    fi
    printf "${D}"
    for ((j = i + 1; j < width; j++)); do printf "━"; done
    printf "${N} ${W}%3d%%${N}" "$pct"

    sleep "$(echo "scale=4; $duration / $width" | bc 2>/dev/null || echo "0.08")"
  done

  echo -e "  ${G}✓${N}"
  tput cnorm 2>/dev/null || true
}

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

init_conf() {
  mkdir -p "$CONF_DIR"
  if [[ ! -f "$CONF_JSON" ]]; then
    cat > "$CONF_JSON" <<'JSON'
{
  "stunnel_port": 4443,
  "mappings": [
    {
      "host": "v2ray.example.com",
      "port": 8443
    }
  ]
}
JSON
    chmod 600 "$CONF_JSON"
  fi
}

read_conf() {
  jq -r '.' "$CONF_JSON" 2>/dev/null || echo "{}"
}

save_conf() {
  local tmp
  tmp="$(mktemp)"
  cat > "$tmp" && mv -f "$tmp" "$CONF_JSON" && chmod 600 "$CONF_JSON"
}

backup_file() {
  local f="$1"
  [[ -f "$f" ]] && cp -a "$f" "${f}${BACKUP_SUFFIX}" && \
    echo -e "  ${D}Backup: ${Y}${f##*/}${BACKUP_SUFFIX}${N}" || true
}

port_in_use() {
  ss -H -lnt 2>/dev/null | awk '{print $4}' | grep -qE "[:.]${1}$"
}

# =========================================================
#  DEPENDENCIAS
# =========================================================

ensure_deps() {
  local need=""
  
  command -v haproxy >/dev/null 2>&1 || need="haproxy"
  command -v jq >/dev/null 2>&1 || need="${need:+$need }jq"
  command -v ss >/dev/null 2>&1 || need="${need:+$need }iproute2"

  if [[ -n "$need" ]]; then
    (
      apt-get update -y >/dev/null 2>&1 || true
      DEBIAN_FRONTEND=noninteractive apt-get install -y $need >/dev/null 2>&1 || true
    ) &
    spinner $! "Instalando dependencias: $need"
  fi

  # Verificar soporte SSL en HAProxy
  if ! haproxy -vv 2>/dev/null | grep -qiE 'SSL|OPENSSL|req_ssl'; then
    echo -e "  ${Y}⚠${N} ${W}HAProxy puede no tener soporte TLS (req_ssl_sni)${N}"
    echo -e "  ${D}Si el ruteo por SNI no funciona, instala haproxy-full${N}"
  fi
}

# =========================================================
#  AUTO-DETECCIÓN
# =========================================================

detect_stunnel_port() {
  local p=""
  local cfg="/etc/stunnel/stunnel.conf"
  
  if [[ -f "$cfg" ]]; then
    p=$(grep -Eo 'accept\s*=\s*[0-9.:]+' "$cfg" 2>/dev/null | awk -F'=' '{print $2}' | \
        sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | awk -F: '{print $NF}' | head -n1 || true)
  fi

  if [[ -z "$p" ]]; then
    p=$(ss -ltnp 2>/dev/null | grep -i stunnel | awk '{print $4}' | awk -F: '{print $NF}' | head -n1 || true)
  fi

  echo "${p:-}"
}

detect_v2ray_port() {
  local p=""
  local files=(/etc/v2ray/config.json /usr/local/etc/v2ray/config.json \
               /etc/xray/config.json /usr/local/etc/xray/config.json)
  
  for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue
    p=$(jq -r '.inbounds[]?.port // empty' "$f" 2>/dev/null | head -n1 || true)
    [[ -n "$p" ]] && { echo "$p"; return; }
  done

  p=$(ss -ltnp 2>/dev/null | grep -E 'v2ray|xray' | awk '{print $4}' | awk -F: '{print $NF}' | head -n1 || true)
  echo "${p:-}"
}

# =========================================================
#  GENERAR HAPROXY CONFIG
# =========================================================

generate_haproxy_cfg() {
  local st_port mappings_json
  st_port=$(jq -r '.stunnel_port // 0' "$CONF_JSON" 2>/dev/null)
  mappings_json=$(jq -c '.mappings' "$CONF_JSON" 2>/dev/null)

  if [[ -z "$st_port" || "$st_port" == "0" ]]; then
    echo -e "  ${R}✗${N} ${W}stunnel_port no definido. Usa 'Setear puerto Stunnel'.${N}"
    return 1
  fi

  backup_file "$HAPROXY_CFG"

  cat > "$HAPROXY_CFG" <<'HAPROXY_EOF'
global
    log /dev/log local0
    maxconn 4096
    daemon

defaults
    mode tcp
    timeout connect 5s
    timeout client 1m
    timeout server 1m

frontend ft_tls
    bind *:443
    tcp-request inspect-delay 5s
    tcp-request content accept if { req_ssl_hello_type 1 }
HAPROXY_EOF

  # Agregar mappings al frontend
  if [[ "$mappings_json" != "null" && -n "$mappings_json" ]]; then
    echo "$mappings_json" | jq -c '.[]' 2>/dev/null | while read -r m; do
      local host port
      host=$(echo "$m" | jq -r '.host' 2>/dev/null)
      port=$(echo "$m" | jq -r '.port' 2>/dev/null)
      [[ -z "$host" || -z "$port" ]] && continue
      echo "    use_backend bk_v_$(echo "$host" | tr '.' '_') if { req.ssl_sni -i ${host} }" >> "$HAPROXY_CFG"
    done
  fi

  echo "    default_backend bk_stunnel" >> "$HAPROXY_CFG"
  echo "" >> "$HAPROXY_CFG"

  # Generar backends para cada mapping
  if [[ "$mappings_json" != "null" && -n "$mappings_json" ]]; then
    echo "$mappings_json" | jq -c '.[]' 2>/dev/null | while read -r m; do
      local host port
      host=$(echo "$m" | jq -r '.host' 2>/dev/null)
      port=$(echo "$m" | jq -r '.port' 2>/dev/null)
      [[ -z "$host" || -z "$port" ]] && continue
      
      cat >> "$HAPROXY_CFG" <<EOF
backend bk_v_$(echo "$host" | tr '.' '_')
    mode tcp
    option tcp-smart-connect
    server v2ray_${host} 127.0.0.1:${port} check

EOF
    done
  fi

  # Backend por defecto para Stunnel
  cat >> "$HAPROXY_CFG" <<EOF
backend bk_stunnel
    mode tcp
    option tcp-smart-connect
    server stunnel_local 127.0.0.1:${st_port} check

EOF

  echo -e "  ${G}✓${N} ${W}haproxy.cfg generado en ${C}${HAPROXY_CFG}${N}"
  return 0
}

# =========================================================
#  SERVICIO SYSTEMD
# =========================================================

install_service() {
  cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=HAProxy Multiplexor Stunnel + V2Ray en 443 (SinNombre)
After=network.target

[Service]
ExecStart=/usr/sbin/haproxy -f $HAPROXY_CFG -db
Restart=always
RestartSec=2s
User=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

  (
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl enable --now "$SERVICE_NAME" >/dev/null 2>&1 || true
    sleep 0.5
  ) &
  spinner $! "Instalando servicio ${SERVICE_NAME}..."
}

uninstall_service() {
  (
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    systemctl disable "$SERVICE_NAME" 2>/dev/null || true
    rm -f "$SERVICE_PATH" 2>/dev/null || true
    systemctl daemon-reload >/dev/null 2>&1 || true
    sleep 0.3
  ) &
  spinner $! "Desinstalando servicio..."
}

service_status() {
  systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null && return 0
  return 1
}

service_status_badge() {
  if service_status; then
    echo -e "${G}${BOLD}● ON${N}"
  else
    echo -e "${R}${BOLD}● OFF${N}"
  fi
}

# =========================================================
#  GESTIÓN DE MAPPINGS
# =========================================================

list_mappings() {
  echo ""
  hr
  echo -e "  ${W}${BOLD}CONFIGURACIÓN ACTUAL${N}"
  hr
  echo ""
  echo -e "  ${W}Archivo:${N} ${C}${CONF_JSON}${N}"
  echo -e "  ${W}Config:${N}  ${C}${HAPROXY_CFG}${N}"
  echo ""
  
  local st_port
  st_port=$(jq -r '.stunnel_port // 0' "$CONF_JSON" 2>/dev/null)
  
  echo -e "  ${W}Puerto Stunnel (por defecto):${N} ${Y}${st_port}${N}"
  echo ""
  echo -e "  ${W}Mappings (V2Ray/SNI):${N}"
  echo ""
  
  local count=0
  jq -r '.mappings[]? | " ▸ \(.host) \u2192 127.0.0.1:\(.port)"' "$CONF_JSON" 2>/dev/null | while read -r line; do
    echo -e "    ${C}${line}${N}"
    count=$((count + 1))
  done
  
  count=$(jq '.mappings[]? | length' "$CONF_JSON" 2>/dev/null | wc -l || echo 0)
  [[ $count -eq 0 ]] && echo -e "    ${D}(ninguno)${N}"
  
  echo ""
  hr
}

add_mapping() {
  clear
  hr
  echo -e "${W}${BOLD}          AGREGAR SNI (MAPPING)${N}"
  hr
  echo ""

  local host=""
  while [[ -z "$host" ]]; do
    echo -ne "  ${W}Dominio/SNI (ej: v2ray.example.com): ${G}"
    read -r host
    echo -ne "${N}"
    host="${host,,}"
    if [[ -z "$host" ]]; then
      echo -e "  ${R}✗${N} ${W}Dominio inválido${N}"
      host=""
      continue
    fi
    
    # Verificar duplicados
    if jq -e ".mappings[] | select(.host == \"$host\")" "$CONF_JSON" >/dev/null 2>&1; then
      echo -e "  ${R}✗${N} ${W}El dominio ${Y}${host}${W} ya existe${N}"
      host=""
      continue
    fi
    echo -e "  ${G}✓${N} ${W}Dominio: ${Y}${host}${N}"
  done

  local port=""
  while [[ -z "$port" ]]; do
    echo -ne "  ${W}Puerto local destino (ej: 8443): ${G}"
    read -r port
    echo -ne "${N}"
    if [[ ! "$port" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
      echo -e "  ${R}✗${N} ${W}Puerto inválido (1-65535)${N}"
      port=""
    fi
  done

  echo ""
  progress_bar "Agregando mapping" 1

  local tmp
  tmp="$(mktemp)"
  jq --arg h "$host" --argjson p "$port" '.mappings += [{host:$h, port:$p}]' "$CONF_JSON" > "$tmp" && \
    mv -f "$tmp" "$CONF_JSON" && chmod 600 "$CONF_JSON"

  if generate_haproxy_cfg && service_status; then
    (
      systemctl restart "$SERVICE_NAME" >/dev/null 2>&1 || true
      sleep 0.5
    ) &
    spinner $! "Reiniciando servicio..."
  fi

  echo ""
  hr
  echo -e "  ${G}${BOLD}✓ Mapping agregado${N}"
  hr
  echo -e "  ${W}Host:${N} ${Y}${host}${N} ${W}━━▸${N} ${C}127.0.0.1:${port}${N}"
  echo ""
  hr
  pause
}

remove_mapping() {
  clear
  hr
  echo -e "${W}${BOLD}          QUITAR SNI (MAPPING)${N}"
  hr
  echo ""

  local mappings_count
  mappings_count=$(jq '.mappings[]? | length' "$CONF_JSON" 2>/dev/null | wc -l || echo 0)

  if [[ $mappings_count -lt 1 ]]; then
    echo -e "  ${Y}⚠${N} ${W}No hay mappings registrados${N}"
    pause
    return
  fi

  echo -e "  ${W}Mappings actuales:${N}"
  echo ""
  
  local n=1
  declare -A MAP=()
  jq -r '.mappings[]? | "\(.host) ▸ \(.port)"' "$CONF_JSON" 2>/dev/null | while read -r line; do
    echo -e "    ${G}[${W}${n}${G}]${N} ${C}${line}${N}"
    n=$((n + 1))
  done

  sep
  echo -ne "  ${W}Número a eliminar (ENTER cancelar): ${G}"
  read -r idx
  echo -ne "${N}"

  if [[ -z "$idx" ]]; then
    echo -e "  ${Y}Cancelado${N}"
    pause
    return
  fi

  if [[ ! "$idx" =~ ^[0-9]+$ ]] || (( idx < 1 )); then
    echo -e "  ${R}✗${N} ${W}Índice inválido${N}"
    pause
    return
  fi

  echo ""
  progress_bar "Eliminando mapping" 1

  local tmp
  tmp="$(mktemp)"
  jq "del(.mappings[$((idx-1))])" "$CONF_JSON" > "$tmp" && \
    mv -f "$tmp" "$CONF_JSON" && chmod 600 "$CONF_JSON"

  if generate_haproxy_cfg && service_status; then
    (
      systemctl restart "$SERVICE_NAME" >/dev/null 2>&1 || true
      sleep 0.5
    ) &
    spinner $! "Reiniciando servicio..."
  fi

  echo ""
  hr
  echo -e "  ${G}${BOLD}✓ Mapping eliminado (índice ${idx})${N}"
  hr
  pause
}

set_stunnel_port() {
  clear
  hr
  echo -e "${W}${BOLD}          SETEAR PUERTO STUNNEL${N}"
  hr
  echo ""

  local current_port
  current_port=$(jq -r '.stunnel_port // 0' "$CONF_JSON" 2>/dev/null)
  echo -e "  ${W}Puerto actual:${N} ${Y}${current_port}${N}"
  echo ""

  local port=""
  while [[ -z "$port" ]]; do
    echo -ne "  ${W}Nuevo puerto (ej 4443): ${G}"
    read -r port
    echo -ne "${N}"
    if [[ ! "$port" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
      echo -e "  ${R}✗${N} ${W}Puerto inválido (1-65535)${N}"
      port=""
      continue
    fi
    if [[ "$port" == "$current_port" ]]; then
      echo -e "  ${Y}⚠${N} ${W}Es el mismo puerto actual${N}"
      port=""
      continue
    fi
    echo -e "  ${G}✓${N} ${W}Nuevo puerto: ${Y}${port}${N}"
  done

  echo ""
  progress_bar "Actualizando puerto" 1

  local tmp
  tmp="$(mktemp)"
  jq --argjson p "$port" '.stunnel_port = $p' "$CONF_JSON" > "$tmp" && \
    mv -f "$tmp" "$CONF_JSON" && chmod 600 "$CONF_JSON"

  if generate_haproxy_cfg && service_status; then
    (
      systemctl restart "$SERVICE_NAME" >/dev/null 2>&1 || true
      sleep 0.5
    ) &
    spinner $! "Reiniciando servicio..."
  fi

  echo ""
  hr
  echo -e "  ${G}${BOLD}✓ Puerto Stunnel actualizado${N}"
  hr
  echo -e "  ${W}Nuevo puerto:${N} ${Y}${port}${N}"
  echo ""
  hr
  pause
}

# =========================================================
#  INSTALAR / DESINSTALAR
# =========================================================

do_install() {
  clear
  hr
  echo -e "${W}${BOLD}          INSTALAR HAPROXY MUX${N}"
  hr
  echo ""

  require_root
  ensure_deps
  init_conf

  echo ""
  sep
  echo -e "  ${W}Paso 1: Generar configuración${N}"
  sep

  generate_haproxy_cfg || { pause; return; }

  echo ""
  sep
  echo -e "  ${W}Paso 2: Instalar servicio systemd${N}"
  sep

  install_service

  echo ""
  hr
  echo -e "  ${G}${BOLD}✓ INSTALACIÓN COMPLETADA${N}"
  hr
  echo ""
  echo -e "  ${W}Servicio:${N}    ${Y}${SERVICE_NAME}${N}  $(service_status_badge)"
  echo -e "  ${W}Puerto:${N}      ${G}443${N}"
  echo -e "  ${W}Config:${N}      ${C}${CONF_JSON}${N}"
  echo ""
  echo -e "  ${D}Próximos pasos:${N}"
  echo -e "    ${C}1.${N} ${W}Instala V2Ray/XRay en puerto 8443 con TLS${N}"
  echo -e "    ${C}2.${N} ${W}Instala Stunnel en puerto 4443${N}"
  echo -e "    ${C}3.${N} ${W}Usa 'Agregar SNI' para registrar dominios${N}"
  echo ""
  hr
  pause
}

do_uninstall() {
  clear
  hr
  echo -e "${W}${BOLD}          DESINSTALAR HAPROXY MUX${N}"
  hr
  echo ""
  echo -e "  ${Y}⚠ Se eliminará completamente:${N}"
  echo -e "    ${W}•${N} Servicio ${C}${SERVICE_NAME}${N}"
  echo -e "    ${W}•${N} Configuración ${C}${CONF_JSON}${N}"
  echo -e "    ${W}•${N} HAProxy config ${C}${HAPROXY_CFG}${N}"
  echo -e "    ${W}•${N} Paquete haproxy y dependencias${N}"
  echo ""
  echo -ne "  ${W}¿Estás seguro? (s/n): ${G}"
  read -r confirm
  echo -ne "${N}"
  [[ "${confirm,,}" == "s" ]] || { echo -e "  ${Y}Cancelado${N}"; pause; return; }

  echo ""
  sep

  uninstall_service

  progress_bar "Eliminando paquetes" 3
  apt-get purge -y haproxy jq iproute2 >/dev/null 2>&1 || true
  apt-get autoremove -y >/dev/null 2>&1 || true

  progress_bar "Limpiando configuración" 2
  rm -rf "$CONF_DIR" >/dev/null 2>&1 || true
  rm -f "$HAPROXY_CFG"* >/dev/null 2>&1 || true
  rm -f /var/log/haproxy.log* >/dev/null 2>&1 || true

  (
    systemctl daemon-reload >/dev/null 2>&1 || true
    journalctl --vacuum-time=1s 2>/dev/null || true
    sleep 0.3
  ) &
  spinner $! "Limpiando restos..."

  echo ""
  hr
  echo -e "  ${G}${BOLD}✓ DESINSTALACIÓN COMPLETADA${N}"
  hr
  echo -e "  ${D}Ya no queda ningún rastro del servicio haproxy-mux${N}"
  echo ""
  hr
  pause
}

detect_ports() {
  clear
  hr
  echo -e "${W}${BOLD}          DETECTAR PUERTOS${N}"
  hr
  echo ""

  (
    sleep 0.5
  ) &
  spinner $! "Escaneando puertos..."

  local sp vp
  sp=$(detect_stunnel_port)
  vp=$(detect_v2ray_port)

  echo ""
  hr
  echo -e "  ${W}Resultados:${N}"
  hr
  echo ""
  echo -e "  ${W}Stunnel:${N}   ${sp:+${Y}${sp}${N}|Detectado}${sp:- ${D}No detectado${N}}"
  echo -e "  ${W}V2Ray:${N}    ${vp:+${Y}${vp}${N}|Detectado}${vp:- ${D}No detectado${N}}"
  echo ""
  
  if [[ -n "$sp" ]]; then
    echo -ne "  ${W}¿Guardar puerto Stunnel ${Y}${sp}${W}? (s/n): ${G}"
    read -r yn
    echo -ne "${N}"
    if [[ "${yn,,}" == "s" ]]; then
      local tmp
      tmp="$(mktemp)"
      jq --argjson p "$sp" '.stunnel_port = $p' "$CONF_JSON" > "$tmp" && \
        mv -f "$tmp" "$CONF_JSON" && chmod 600 "$CONF_JSON"
      echo -e "  ${G}✓${N} ${W}Guardado${N}"
    fi
  fi

  echo ""
  hr
  pause
}

# =========================================================
#  AYUDA
# =========================================================

show_help() {
  clear
  cat <<'EOF'

╔══════════════════════════════════════════════════════╗
║   HAProxy MUX - Guía de Uso (SinNombre v2.0)       ║
╚══════════════════════════════════════════════════════╝

┌─ OBJETIVO ─────────────────────────────────────────┐
│ Multiplexar TLS en puerto 443 usando SNI:          │
│   • V2Ray/XRay (por dominio) → 127.0.0.1:8443     │
│   • Stunnel (por defecto)     → 127.0.0.1:4443    │
└────────────────────────────────────────────────────┘

┌─ FLUJO RECOMENDADO ────────────────────────────────┐
│ 1. Instala V2Ray/XRay con TLS en puerto 8443      │
│    Config SNI = dominio que registrarás           │
│                                                    │
│ 2. Instala Stunnel escuchando en puerto 4443      │
│                                                    │
│ 3. Ejecuta "Instalar" desde este panel            │
│    • Genera haproxy.cfg                           │
│    • Activa el servicio haproxy-mux               │
│                                                    │
│ 4. Usa "Agregar SNI" para cada dominio V2Ray      │
│                                                    │
│ 5. HAProxy rutea en base a SNI:                   │
│    • v2ray.example.com → puerto 8443              │
│    • Otros SNIs        → puerto 4443 (Stunnel)    │
└────────────────────────────────────────────────────┘

┌─ VERIFICACIÓN ─────────────────────────────────────┐
│ $ ss -ltnp | grep haproxy                          │
│ $ journalctl -u haproxy-mux -n 50                  │
│ $ cat /etc/SN/haproxy-mux.json                     │
└────────────────────────────────────────────────────┘

┌─ NOTAS IMPORTANTES ────────────────────────────────┐
│ • El ruteo se basa en SNI (req.ssl_sni)           │
│ • Los clientes V2Ray deben enviar SNI correcto    │
│ • V2Ray y Stunnel NO pueden usar el mismo SNI     │
│ • HAProxy requiere soporte TLS (haproxy-full)     │
│ • Puerto 443 requiere permisos root               │
│ • Backup automático: .sn-bak-YYYYMMDDHHMMSS      │
└────────────────────────────────────────────────────┘

EOF
  pause
}

# =========================================================
#  MENÚ PRINCIPAL
# =========================================================

main_menu() {
  require_root
  init_conf
  ensure_deps

  while true; do
    clear
    local status
    if service_status; then
      status="${G}${BOLD}● ACTIVO${N}"
    else
      status="${R}${BOLD}● INACTIVO${N}"
    fi

    hr
    echo -e "${W}${BOLD}         HAProxy MUX - Stunnel + V2Ray (SNI)${N}"
    hr
    echo -e "  ${W}Estado:${N}    ${status}"
    echo -e "  ${W}Puerto:${N}    ${G}443${N}"
    echo -e "  ${W}Servicio:${N}  ${Y}${SERVICE_NAME}${N}"
    hr
    echo ""
    echo -e "  ${G}[${W}1${G}]${N}  ${C}Instalar / Activar${N}"
    echo -e "  ${G}[${W}2${G}]${N}  ${C}Desinstalar / Desactivar${N}"
    sep
    echo -e "  ${G}[${W}3${G}]${N}  ${C}Detectar puertos (auto)${N}"
    echo -e "  ${G}[${W}4${G}]${N}  ${C}Ver mappings y configuración${N}"
    echo -e "  ${G}[${W}5${G}]${N}  ${C}Agregar SNI (mapping)${N}"
    echo -e "  ${G}[${W}6${G}]${N}  ${C}Quitar SNI (mapping)${N}"
    echo -e "  ${G}[${W}7${G}]${N}  ${C}Setear puerto Stunnel${N}"
    sep
    echo -e "  ${G}[${W}8${G}]${N}  ${C}Reiniciar servicio${N}"
    echo -e "  ${G}[${W}9${G}]${N}  ${C}Ayuda / Indicaciones de uso${N}"
    hr
    echo -e "  ${G}[${W}0${G}]${N}  ${W}Volver${N}"
    hr
    echo ""
    echo -ne "  ${W}Opción: ${G}"
    read -r opt
    echo -ne "${N}"

    case "${opt:-}" in
      1) do_install ;;
      2) do_uninstall ;;
      3) detect_ports ;;
      4) list_mappings; pause ;;
      5) add_mapping ;;
      6) remove_mapping ;;
      7) set_stunnel_port ;;
      8)
         if service_status; then
           (
             systemctl restart "$SERVICE_NAME" >/dev/null 2>&1 || true
             sleep 0.5
           ) &
           spinner $! "Reiniciando servicio..."
           echo -e "  ${G}✓${N} ${W}Servicio reiniciado${N}"
         else
           echo -e "  ${Y}⚠${N} ${W}Servicio no está activo${N}"
         fi
         sleep 1
         ;;
      9) show_help ;;
      0) break ;;
      *) echo -e "  ${R}Opción inválida${N}"; sleep 1 ;;
    esac
  done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main_menu
fi
