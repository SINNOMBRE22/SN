#!/bin/bash
# =========================================================
# SinNombre v2.0 - UDP CUSTOM MANAGER
# Archivo: SN/Protocolos/udp-custom.sh
#
# CAMBIOS v2.0 (2026-03-05):
# - Usa lib/colores.sh (sin colores duplicados)
# - Barra de progreso fina (━╸) + spinner profesional
# - Menú simplificado con estado en header
# - Desinstalación real y completa
# - Flujo de instalación directo con animaciones
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

# ── Rutas y configuración ──────────────────────────────
CONFIG_DIR="/root/udp"
CONFIG_FILE="$CONFIG_DIR/config.json"
LOG_FILE="/var/log/udp-custom.log"
SERVICE_NAME="udp-custom"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
UDP_BIN="$CONFIG_DIR/udp-custom"

DEFAULT_UDP_PORT=36712
DEFAULT_PORT_RANGE="1-65535"
FD_LIMIT=1048576

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
    hr
    exit 1
  fi
}

get_public_ip() {
  curl -fsS --max-time 2 ifconfig.me 2>/dev/null \
    || curl -fsS --max-time 2 https://api.ipify.org 2>/dev/null \
    || echo "No disponible"
}

is_installed() {
  [[ -x "$UDP_BIN" ]] && [[ -f "$CONFIG_FILE" ]] && [[ -f "$SERVICE_FILE" ]]
}

is_running() {
  systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null
}

status_badge() {
  if is_running; then
    echo -e "${G}${BOLD}● ON${N}"
  else
    echo -e "${R}${BOLD}● OFF${N}"
  fi
}

get_udp_port() {
  if [[ -f "$CONFIG_FILE" ]] && command -v jq >/dev/null 2>&1; then
    local port
    port=$(jq -r '.listen // empty' "$CONFIG_FILE" 2>/dev/null | sed 's/://')
    [[ -n "$port" && "$port" != "null" ]] && { echo "$port"; return; }
  fi
  echo "$DEFAULT_UDP_PORT"
}

get_port_range() {
  if [[ -f "$CONFIG_FILE" ]] && command -v jq >/dev/null 2>&1; then
    local range
    range=$(jq -r '.port_range // empty' "$CONFIG_FILE" 2>/dev/null)
    [[ -n "$range" && "$range" != "null" ]] && { echo "$range"; return; }
  fi
  echo "$DEFAULT_PORT_RANGE"
}

get_udp_connections() {
  local port
  port="$(get_udp_port)"
  ss -u -a 2>/dev/null | grep -cE ":${port}\b" || echo "0"
}

wait_for_port() {
  local port="$1"
  for _ in {1..15}; do
    ss -ulpn 2>/dev/null | grep -q ":${port}\b" && return 0
    sleep 1
  done
  return 1
}

ensure_deps() {
  local missing=()
  for bin in jq curl wget; do
    command -v "$bin" >/dev/null 2>&1 || missing+=("$bin")
  done
  if (( ${#missing[@]} > 0 )); then
    (
      apt-get update -y >/dev/null 2>&1 || true
      apt-get install -y "${missing[@]}" net-tools >/dev/null 2>&1 || true
    ) &
    spinner $! "Instalando dependencias (${missing[*]})..."
  fi
}

# =========================================================
#  INSTALAR UDP-CUSTOM
# =========================================================
install_udp() {
  clear
  hr
  echo -e "${W}${BOLD}          INSTALAR UDP-CUSTOM${N}"
  hr
  echo ""

  ensure_deps
  mkdir -p "$CONFIG_DIR"

  # Paso 1: Descargar binario
  if [[ ! -x "$UDP_BIN" ]]; then
    (
      wget -qO "$UDP_BIN" \
        "https://github.com/http-custom/udpcustom/raw/main/folder/udp-custom-linux-amd64.bin" 2>/dev/null \
      || curl -fsSL -o "$UDP_BIN" \
        "https://github.com/http-custom/udpcustom/raw/main/folder/udp-custom-linux-amd64.bin" 2>/dev/null
      chmod +x "$UDP_BIN" 2>/dev/null || true
    ) &
    spinner $! "Descargando UDP-Custom..."

    if [[ ! -x "$UDP_BIN" ]]; then
      echo -e "  ${R}✗${N} ${W}Error al descargar${N}"
      pause
      return
    fi
  else
    echo -e "  ${G}✓${N} ${W}Binario ya existe${N}"
  fi

  # Paso 2: Configurar puerto
  echo ""
  sep
  echo -e "  ${C}Configuración UDP-Custom${N}"
  sep
  echo ""

  local udp_port=""
  while true; do
    echo -ne "  ${W}Puerto UDP [${D}${DEFAULT_UDP_PORT}${W}]: ${G}"
    read -r udp_port
    echo -ne "${N}"
    udp_port="${udp_port:-$DEFAULT_UDP_PORT}"
    if [[ "$udp_port" =~ ^[0-9]+$ ]] && (( udp_port >= 1 && udp_port <= 65535 )); then
      break
    fi
    echo -e "  ${R}✗${N} ${W}Puerto inválido (1-65535)${N}"
  done

  local port_range=""
  while true; do
    echo -ne "  ${W}Rango de puertos [${D}${DEFAULT_PORT_RANGE}${W}]: ${G}"
    read -r port_range
    echo -ne "${N}"
    port_range="${port_range:-$DEFAULT_PORT_RANGE}"
    if [[ "$port_range" =~ ^[0-9]+-[0-9]+$ ]]; then
      break
    fi
    echo -e "  ${R}✗${N} ${W}Formato inválido (ej: 1-65535)${N}"
  done

  # Paso 3: Crear config.json
  progress_bar "Creando configuración" 1
  cat > "$CONFIG_FILE" <<EOF
{
  "listen": ":${udp_port}",
  "port_range": "${port_range}",
  "stream_buffer": 16777216,
  "receive_buffer": 33554432,
  "auth": {
    "mode": "passwords"
  }
}
EOF

  # Paso 4: Optimizar sistema
  progress_bar "Optimizando kernel UDP" 2
  cat > /etc/sysctl.d/99-udp-custom.conf <<EOF
net.core.rmem_max=33554432
net.core.wmem_max=33554432
net.core.rmem_default=8388608
net.core.wmem_default=8388608
net.core.netdev_max_backlog=500000
net.core.somaxconn=8192
net.ipv4.ip_local_port_range=1024 65535
net.ipv4.udp_mem=4096 87380 33554432
net.ipv4.udp_rmem_min=131072
net.ipv4.udp_wmem_min=131072
EOF
  sysctl -p /etc/sysctl.d/99-udp-custom.conf >/dev/null 2>&1 || true

  # Paso 5: Crear log
  touch "$LOG_FILE" 2>/dev/null || true
  chmod 644 "$LOG_FILE" 2>/dev/null || true

  # Paso 6: Crear servicio systemd
  progress_bar "Creando servicio systemd" 2
  cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=UDP Custom Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$CONFIG_DIR
ExecStart=$UDP_BIN server -c $CONFIG_FILE
Restart=always
RestartSec=3
StandardOutput=append:$LOG_FILE
StandardError=append:$LOG_FILE
LimitNOFILE=$FD_LIMIT
Nice=-5
IOSchedulingClass=best-effort
IOSchedulingPriority=2

[Install]
WantedBy=multi-user.target
EOF

  # Paso 7: Iniciar servicio
  (
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl enable "$SERVICE_NAME" >/dev/null 2>&1 || true
    systemctl start "$SERVICE_NAME" >/dev/null 2>&1 || true
    sleep 2
  ) &
  spinner $! "Iniciando servicio UDP-Custom..."

  echo ""

  if is_running && wait_for_port "$udp_port"; then
    hr
    echo -e "  ${G}${BOLD}✓ UDP-CUSTOM INSTALADO Y ACTIVO${N}"
    hr
    echo ""
    echo -e "  ${W}Puerto UDP:${N}    ${Y}${udp_port}${N}"
    echo -e "  ${W}Rango:${N}         ${C}${port_range}${N}"
    echo -e "  ${W}Config:${N}        ${C}${CONFIG_FILE}${N}"
    echo -e "  ${W}Logs:${N}          ${C}${LOG_FILE}${N}"
    echo ""
    hr
  else
    hr
    echo -e "  ${Y}⚠ Servicio instalado pero el puerto ${udp_port} no respondió a tiempo${N}"
    hr
    echo -e "  ${D}Puede tardar unos segundos. Revisa con la opción de logs.${N}"
  fi

  pause
}

# =========================================================
#  MODIFICAR CONFIGURACIÓN
# =========================================================
modify_config() {
  clear
  hr
  echo -e "${W}${BOLD}          MODIFICAR CONFIGURACIÓN${N}"
  hr

  if ! is_installed; then
    echo -e "  ${R}✗${N} ${W}UDP-Custom no está instalado${N}"
    pause
    return
  fi

  local current_port current_range
  current_port="$(get_udp_port)"
  current_range="$(get_port_range)"

  echo ""
  echo -e "  ${W}Configuración actual:${N}"
  echo -e "    ${W}Puerto:${N} ${Y}${current_port}${N}"
  echo -e "    ${W}Rango:${N}  ${C}${current_range}${N}"
  sep
  echo ""

  # Puerto
  local new_port=""
  while true; do
    echo -ne "  ${W}Nuevo puerto [${D}${current_port}${W}]: ${G}"
    read -r new_port
    echo -ne "${N}"
    new_port="${new_port:-$current_port}"
    if [[ "$new_port" =~ ^[0-9]+$ ]] && (( new_port >= 1 && new_port <= 65535 )); then
      break
    fi
    echo -e "  ${R}✗${N} ${W}Puerto inválido${N}"
  done

  # Rango
  local new_range=""
  while true; do
    echo -ne "  ${W}Nuevo rango [${D}${current_range}${W}]: ${G}"
    read -r new_range
    echo -ne "${N}"
    new_range="${new_range:-$current_range}"
    if [[ "$new_range" =~ ^[0-9]+-[0-9]+$ ]]; then
      break
    fi
    echo -e "  ${R}✗${N} ${W}Formato inválido (ej: 1-65535)${N}"
  done

  echo ""

  # Aplicar cambios
  if command -v jq >/dev/null 2>&1; then
    progress_bar "Actualizando configuración" 2
    jq ".listen = \":${new_port}\" | .port_range = \"${new_range}\"" \
      "$CONFIG_FILE" > /tmp/udp_config.tmp 2>/dev/null \
      && mv /tmp/udp_config.tmp "$CONFIG_FILE"
  else
    echo -e "  ${Y}⚠${N} ${W}jq no disponible, reescribiendo config${N}"
    cat > "$CONFIG_FILE" <<EOF
{
  "listen": ":${new_port}",
  "port_range": "${new_range}",
  "stream_buffer": 16777216,
  "receive_buffer": 33554432,
  "auth": {
    "mode": "passwords"
  }
}
EOF
  fi

  # Reiniciar
  (
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl restart "$SERVICE_NAME" >/dev/null 2>&1 || true
    sleep 2
  ) &
  spinner $! "Reiniciando con nueva configuración..."

  echo ""
  hr
  if is_running; then
    echo -e "  ${G}${BOLD}✓ Configuración actualizada${N}"
    echo -e "  ${W}Puerto:${N} ${Y}${new_port}${N}  ${W}Rango:${N} ${C}${new_range}${N}"
  else
    echo -e "  ${R}✗ Error al reiniciar con la nueva configuración${N}"
  fi
  hr
  pause
}

# =========================================================
#  INICIAR / PARAR
# =========================================================
toggle_service() {
  clear
  hr

  if is_running; then
    (
      systemctl stop "$SERVICE_NAME" >/dev/null 2>&1 || true
      sleep 0.5
    ) &
    spinner $! "Deteniendo UDP-Custom..."
    echo -e "  ${Y}■ Servicio detenido${N}"
  else
    (
      systemctl start "$SERVICE_NAME" >/dev/null 2>&1 || true
      sleep 2
    ) &
    spinner $! "Iniciando UDP-Custom..."

    local port
    port="$(get_udp_port)"
    if is_running && wait_for_port "$port"; then
      echo -e "  ${G}${BOLD}✓ Servicio iniciado (puerto ${port})${N}"
    else
      echo -e "  ${R}✗ Error al iniciar${N}"
    fi
  fi

  hr
  pause
}

# =========================================================
#  VER LOGS
# =========================================================
show_logs() {
  clear
  hr
  echo -e "  ${W}${BOLD}LOGS UDP-CUSTOM${N} ${D}(últimas 30 líneas)${N}"
  hr
  echo ""

  if [[ -f "$LOG_FILE" ]] && [[ -s "$LOG_FILE" ]]; then
    echo -e "${D}$(tail -n 30 "$LOG_FILE")${N}"
  else
    local journal_output
    journal_output="$(journalctl -u "$SERVICE_NAME" -n 30 --no-pager 2>/dev/null || true)"
    if [[ -n "$journal_output" ]]; then
      echo -e "${D}${journal_output}${N}"
    else
      echo -e "  ${Y}⚠${N} ${W}No hay logs disponibles${N}"
    fi
  fi

  echo ""
  hr
  pause
}

# =========================================================
#  DESINSTALAR
# =========================================================
uninstall_udp() {
  clear
  hr
  echo -e "${W}${BOLD}          DESINSTALAR UDP-CUSTOM${N}"
  hr

  if ! is_installed && [[ ! -f "$SERVICE_FILE" ]]; then
    echo -e "  ${Y}⚠${N} ${W}UDP-Custom no está instalado${N}"
    pause
    return
  fi

  echo ""
  echo -e "  ${Y}⚠ Se eliminará completamente:${N}"
  echo -e "    ${W}•${N} Binario y configuración ${C}${CONFIG_DIR}/${N}"
  echo -e "    ${W}•${N} Servicio systemd ${C}${SERVICE_NAME}${N}"
  echo -e "    ${W}•${N} Logs ${C}${LOG_FILE}${N}"
  echo -e "    ${W}•${N} Optimizaciones del kernel"
  echo ""
  echo -ne "  ${W}¿Estás seguro? (s/n): ${G}"
  read -r confirm
  echo -ne "${N}"
  [[ "${confirm,,}" == "s" ]] || { echo -e "  ${Y}Cancelado${N}"; pause; return; }

  echo ""
  sep

  (
    systemctl stop "$SERVICE_NAME" >/dev/null 2>&1 || true
    systemctl disable "$SERVICE_NAME" >/dev/null 2>&1 || true
    sleep 0.5
  ) &
  spinner $! "Deteniendo servicio..."

  progress_bar "Eliminando archivos" 2
  rm -f "$SERVICE_FILE" >/dev/null 2>&1 || true
  rm -f "$UDP_BIN" >/dev/null 2>&1 || true
  rm -rf "$CONFIG_DIR" >/dev/null 2>&1 || true
  rm -f "$LOG_FILE" >/dev/null 2>&1 || true

  progress_bar "Limpiando optimizaciones" 1
  rm -f /etc/sysctl.d/99-udp-custom.conf >/dev/null 2>&1 || true
  sysctl --system >/dev/null 2>&1 || true

  (
    systemctl daemon-reload >/dev/null 2>&1 || true
    sleep 0.3
  ) &
  spinner $! "Recargando systemd..."

  echo ""
  hr
  echo -e "  ${G}${BOLD}✓ UDP-CUSTOM DESINSTALADO COMPLETAMENTE${N}"
  hr
  echo ""
  sleep 1
  pause
}

# =========================================================
#  MENÚ PRINCIPAL
# =========================================================
main_menu() {
  require_root

  while true; do
    clear

    local ip_pub port_udp range_udp conns

    hr
    echo -e "${W}${BOLD}              UDP CUSTOM MANAGER${N}"
    hr

    if is_installed; then
      ip_pub="$(get_public_ip)"
      port_udp="$(get_udp_port)"
      range_udp="$(get_port_range)"
      conns="$(get_udp_connections)"

      echo -e "  ${W}IP Pública:${N}    ${Y}${ip_pub}${N}"
      echo -e "  ${W}ESTADO:${N}        $(status_badge)"
      echo -e "  ${W}Puerto UDP:${N}    ${Y}${port_udp}${N}"
      echo -e "  ${W}Rango:${N}         ${C}${range_udp}${N}"
      echo -e "  ${W}Conexiones:${N}    ${C}${conns}${N}"
      hr
      echo ""
      echo -e "  ${G}[${W}1${G}]${N}  ${C}Iniciar / Parar${N}  $(status_badge)"
      echo -e "  ${G}[${W}2${G}]${N}  ${C}Modificar configuración${N}"
      echo -e "  ${G}[${W}3${G}]${N}  ${C}Ver logs${N}"
      sep
      echo -e "  ${G}[${W}4${G}]${N}  ${R}Desinstalar${N}"
      hr
      echo -e "  ${G}[${W}0${G}]${N}  ${W}Volver${N}"
      hr
      echo ""
      echo -ne "  ${W}Opción: ${G}"
      read -r op
      echo -ne "${N}"

      case "${op:-}" in
        1) toggle_service ;;
        2) modify_config ;;
        3) show_logs ;;
        4) uninstall_udp; is_installed || continue ;;
        0) break ;;
        *) echo -e "  ${R}Opción inválida${N}"; sleep 1 ;;
      esac
    else
      echo -e "  ${W}ESTADO:${N}  ${R}${BOLD}● NO INSTALADO${N}"
      hr
      echo ""
      echo -e "  ${G}[${W}1${G}]${N}  ${C}Instalar UDP-Custom${N}"
      hr
      echo -e "  ${G}[${W}0${G}]${N}  ${W}Volver${N}"
      hr
      echo ""
      echo -ne "  ${W}Opción: ${G}"
      read -r op
      echo -ne "${N}"

      case "${op:-}" in
        1) install_udp ;;
        0) break ;;
        *) echo -e "  ${R}Opción inválida${N}"; sleep 1 ;;
      esac
    fi
  done
}

trap 'echo -ne "${N}"; tput cnorm 2>/dev/null; exit 0' SIGINT SIGTERM

main_menu
