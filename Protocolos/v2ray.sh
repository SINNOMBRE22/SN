#!/bin/bash
# =========================================================
# SinNombre v2.0 - V2RAY MANAGER
# Archivo: SN/Protocolos/v2ray.sh
#
# CAMBIOS v2.0 (2026-03-05):
# - Usa lib/colores.sh (sin colores duplicados)
# - Barra de progreso fina (━╸) + spinner profesional
# - Usa Sistema/go.sh local para instalar (no descarga externo)
# - Menú con estado ON/OFF, puerto, protocolo en header
# - Desinstalación real con animaciones
# - Corrección de errores y validaciones
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

# ── Rutas ───────────────────────────────────────────────
LOGFILE="/var/log/v2ray_manager.log"
SN_DIR="/etc/SN"
VPS_crt="/etc/SN/cert"
config="/etc/v2ray/config.json"

mkdir -p "$SN_DIR" "$VPS_crt" "$(dirname "$LOGFILE")" 2>/dev/null || true

# =========================================================
#  ANIMACIONES
# =========================================================

progress_bar() {
  local msg="$1"
  local duration="${2:-3}"
  local width=30
  tput civis 2>/dev/null || true
  for ((i = 0; i <= width; i++)); do
    local pct=$(( i * 100 / width ))
    local bar_color="$R"
    (( pct > 33 )) && bar_color="$Y"
    (( pct > 66 )) && bar_color="$G"
    printf "\r  ${C}•${N} ${W}%-25s${N} " "$msg"
    printf "${bar_color}"
    for ((j = 0; j < i; j++)); do printf "━"; done
    if (( i < width )); then printf "╸"; else printf "━"; fi
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
    hr
    exit 1
  fi
}

log_msg() {
  echo "$(date '+%Y-%m-%d %H:%M:%S'): $*" >> "$LOGFILE"
}

is_installed() {
  command -v v2ray >/dev/null 2>&1 || [[ -f /usr/bin/v2ray/v2ray ]]
}

config_exists() {
  [[ -f "$config" ]]
}

is_running() {
  systemctl is-active --quiet v2ray 2>/dev/null
}

status_badge() {
  if is_running; then
    echo -e "${G}${BOLD}● ON${N}"
  else
    echo -e "${R}${BOLD}● OFF${N}"
  fi
}

get_port() {
  if config_exists; then
    jq -r '.inbounds[0].port // "N/A"' "$config" 2>/dev/null || echo "N/A"
  else
    echo "N/A"
  fi
}

get_protocol() {
  if config_exists; then
    jq -r '.inbounds[0].protocol // "N/A"' "$config" 2>/dev/null || echo "N/A"
  else
    echo "N/A"
  fi
}

get_network() {
  if config_exists; then
    jq -r '.inbounds[0].streamSettings.network // "N/A"' "$config" 2>/dev/null || echo "N/A"
  else
    echo "N/A"
  fi
}

get_tls() {
  if config_exists; then
    jq -r '.inbounds[0].streamSettings.security // "none"' "$config" 2>/dev/null || echo "none"
  else
    echo "none"
  fi
}

get_users_count() {
  if config_exists; then
    jq '.inbounds[0].settings.clients | length' "$config" 2>/dev/null || echo "0"
  else
    echo "0"
  fi
}

v2ray_restart() {
  (
    if command -v v2ray >/dev/null 2>&1; then
      v2ray restart >/dev/null 2>&1 || true
    else
      systemctl restart v2ray >/dev/null 2>&1 || true
    fi
    sleep 1
  ) &
  spinner $! "Reiniciando V2Ray..."

  if is_running; then
    echo -e "  ${G}✓${N} ${W}V2Ray reiniciado correctamente${N}"
    log_msg "V2Ray reiniciado"
  else
    echo -e "  ${R}✗${N} ${W}Fallo al reiniciar V2Ray${N}"
    log_msg "Error en restart"
  fi
}

# =========================================================
#  INSTALAR V2RAY
# =========================================================
install_v2ray() {
  clear
  hr
  echo -e "${W}${BOLD}          INSTALAR V2RAY${N}"
  hr
  echo ""

  if is_installed && config_exists; then
    echo -e "  ${Y}⚠${N} ${W}V2Ray ya está instalado${N}"
    echo -ne "  ${W}¿Reinstalar? (s/n): ${G}"
    read -r confirm
    echo -ne "${N}"
    [[ "${confirm,,}" == "s" ]] || { pause; return; }
  fi

  local installer="$ROOT_DIR/Sistema/v2ray.sh"
  if [[ ! -f "$installer" ]]; then
    echo -e "  ${R}✗${N} ${W}No se encontró el instalador${N}"
    echo -e "  ${D}Ruta esperada: ${installer}${N}"
    pause
    return
  fi

  echo ""
  log_msg "Iniciando instalación V2Ray"

  chmod +x "$installer"
  bash "$installer"

  echo ""
  if is_installed && config_exists; then
    hr
    echo -e "  ${G}${BOLD}✓ V2RAY INSTALADO${N}"
    hr
    echo ""
    echo -e "  ${W}Puerto:${N}     ${Y}$(get_port)${N}"
    echo -e "  ${W}Protocolo:${N}  ${C}$(get_protocol)${N}"
    echo -e "  ${W}Network:${N}    ${C}$(get_network)${N}"
    echo ""
    log_msg "Instalación completada"
  else
    echo -e "  ${R}✗${N} ${W}La instalación puede haber fallado${N}"
    echo -e "  ${D}Revisa los logs para más información${N}"
    log_msg "Instalación posiblemente fallida"
  fi

  hr
  pause
}

# =========================================================
#  DESINSTALAR V2RAY
# =========================================================
uninstall_v2ray() {
  clear
  hr
  echo -e "${W}${BOLD}          DESINSTALAR V2RAY${N}"
  hr

  if ! is_installed && ! config_exists; then
    echo -e "  ${Y}⚠${N} ${W}V2Ray no está instalado${N}"
    pause
    return
  fi

  echo ""
  echo -e "  ${Y}⚠ Se eliminará completamente:${N}"
  echo -e "    ${W}•${N} Binarios V2Ray / Xray"
  echo -e "    ${W}•${N} Configuración ${C}/etc/v2ray/${N}"
  echo -e "    ${W}•${N} Logs y utilidades"
  echo -e "    ${W}•${N} Servicios systemd"
  echo ""
  echo -ne "  ${W}¿Estás seguro? (s/n): ${G}"
  read -r confirm
  echo -ne "${N}"
  [[ "${confirm,,}" == "s" ]] || { echo -e "  ${Y}Cancelado${N}"; pause; return; }

  echo ""
  sep
  log_msg "Iniciando desinstalación V2Ray"

  # Paso 1: Detener servicios
  (
    systemctl stop v2ray >/dev/null 2>&1 || true
    systemctl stop xray >/dev/null 2>&1 || true
    systemctl disable v2ray >/dev/null 2>&1 || true
    systemctl disable xray >/dev/null 2>&1 || true
    sleep 0.5
  ) &
  spinner $! "Deteniendo servicios..."

  # Paso 2: Ejecutar removedor si existe
  local go_sh="$ROOT_DIR/Sistema/go.sh"
  if [[ -f "$go_sh" ]]; then
    (
      bash "$go_sh" --remove >/dev/null 2>&1 || true
      bash "$go_sh" --remove -x >/dev/null 2>&1 || true
    ) &
    spinner $! "Ejecutando removedor..."
  fi

  # Paso 3: Limpiar archivos
  progress_bar "Eliminando archivos" 3
  rm -rf /etc/v2ray /var/log/v2ray >/dev/null 2>&1 || true
  rm -rf /etc/xray /var/log/xray >/dev/null 2>&1 || true
  rm -rf /usr/bin/v2ray /usr/bin/xray >/dev/null 2>&1 || true
  rm -rf /usr/local/bin/v2ray /usr/local/bin/xray >/dev/null 2>&1 || true
  rm -rf /etc/v2ray_util >/dev/null 2>&1 || true
  rm -f /usr/share/bash-completion/completions/v2ray >/dev/null 2>&1 || true
  rm -f /usr/share/bash-completion/completions/xray >/dev/null 2>&1 || true
  rm -f /etc/systemd/system/v2ray.service >/dev/null 2>&1 || true
  rm -f /etc/systemd/system/xray.service >/dev/null 2>&1 || true
  rm -f /lib/systemd/system/v2ray.service >/dev/null 2>&1 || true
  rm -f /lib/systemd/system/xray.service >/dev/null 2>&1 || true

  # Paso 4: Limpiar pip y cron
  (
    pip uninstall v2ray_util -y >/dev/null 2>&1 || true
    crontab -l 2>/dev/null | sed '/v2ray/d;/xray/d' | crontab - 2>/dev/null || true
    sed -i '/v2ray/d;/xray/d' ~/.bashrc 2>/dev/null || true
    systemctl daemon-reload >/dev/null 2>&1 || true
    sleep 0.3
  ) &
  spinner $! "Limpiando utilidades y cron..."

  echo ""
  hr
  echo -e "  ${G}${BOLD}✓ V2RAY DESINSTALADO COMPLETAMENTE${N}"
  hr
  log_msg "V2Ray desinstalado"
  echo ""
  sleep 1
  pause
}

# =========================================================
#  CONFIGURAR PUERTO
# =========================================================
config_port() {
  clear
  hr
  echo -e "${W}${BOLD}          CONFIGURAR PUERTO V2RAY${N}"
  hr

  if ! config_exists; then
    echo -e "  ${R}✗${N} ${W}Config no encontrado${N}"
    pause
    return
  fi

  local current
  current="$(get_port)"
  echo ""
  echo -e "  ${W}Puerto actual:${N} ${Y}${current}${N}"
  sep

  local new_port=""
  while true; do
    echo -ne "  ${W}Nuevo puerto [${D}1-65535${W}]: ${G}"
    read -r new_port
    echo -ne "${N}"
    [[ "$new_port" == "0" ]] && return
    if [[ -z "$new_port" ]]; then
      echo -e "  ${R}✗${N} ${W}Ingresa un puerto${N}"
    elif [[ ! "$new_port" =~ ^[0-9]+$ ]] || (( new_port < 1 || new_port > 65535 )); then
      echo -e "  ${R}✗${N} ${W}Puerto inválido (1-65535)${N}"
    else
      break
    fi
  done

  local temp
  temp=$(mktemp)
  jq --argjson p "$new_port" '.inbounds[0].port = $p' "$config" > "$temp" && mv "$temp" "$config"
  chmod 644 "$config"

  echo ""
  v2ray_restart

  echo ""
  echo -e "  ${G}✓${N} ${W}Puerto cambiado a ${Y}${new_port}${N}"
  pause
}

# =========================================================
#  CONFIGURAR ALTERID
# =========================================================
config_alterid() {
  clear
  hr
  echo -e "${W}${BOLD}          CONFIGURAR ALTERID${N}"
  hr

  if ! config_exists; then
    echo -e "  ${R}✗${N} ${W}Config no encontrado${N}"
    pause
    return
  fi

  local current
  current="$(jq -r '.inbounds[0].settings.clients[0].alterId // "N/A"' "$config" 2>/dev/null)"
  echo ""
  echo -e "  ${W}AlterId actual:${N} ${Y}${current}${N}"
  sep

  local new_aid=""
  while true; do
    echo -ne "  ${W}Nuevo alterId: ${G}"
    read -r new_aid
    echo -ne "${N}"
    [[ "$new_aid" == "0" ]] && return
    if [[ -z "$new_aid" ]]; then
      echo -e "  ${R}✗${N} ${W}Ingresa un valor${N}"
    elif [[ ! "$new_aid" =~ ^[0-9]+$ ]]; then
      echo -e "  ${R}✗${N} ${W}Solo números${N}"
    else
      break
    fi
  done

  local temp
  temp=$(mktemp)
  jq --argjson a "$new_aid" '.inbounds[0].settings.clients[].alterId = $a' "$config" > "$temp" && mv "$temp" "$config"
  chmod 644 "$config"

  echo ""
  v2ray_restart

  echo ""
  echo -e "  ${G}✓${N} ${W}AlterId cambiado a ${Y}${new_aid}${N}"
  pause
}

# =========================================================
#  CONFIGURAR ADDRESS
# =========================================================
config_address() {
  clear
  hr
  echo -e "${W}${BOLD}          CONFIGURAR ADDRESS${N}"
  hr

  if ! config_exists; then
    echo -e "  ${R}✗${N} ${W}Config no encontrado${N}"
    pause
    return
  fi

  local current
  current="$(jq -r '.inbounds[0].domain // empty' "$config" 2>/dev/null)"
  [[ -z "$current" || "$current" == "null" ]] && current="$(curl -fsS --max-time 2 ifconfig.me 2>/dev/null || echo 'N/A')"
  echo ""
  echo -e "  ${W}Address actual:${N} ${Y}${current}${N}"
  sep

  echo -ne "  ${W}Nuevo address: ${G}"
  read -r new_addr
  echo -ne "${N}"
  [[ -z "$new_addr" || "$new_addr" == "0" ]] && return

  local temp
  temp=$(mktemp)
  jq --arg a "$new_addr" '.inbounds[0].domain = $a' "$config" > "$temp" && mv "$temp" "$config"
  chmod 644 "$config"

  echo ""
  v2ray_restart

  echo ""
  echo -e "  ${G}✓${N} ${W}Address cambiado a ${Y}${new_addr}${N}"
  pause
}

# =========================================================
#  CONFIGURAR HOST
# =========================================================
config_host() {
  clear
  hr
  echo -e "${W}${BOLD}          CONFIGURAR HOST${N}"
  hr

  if ! config_exists; then
    echo -e "  ${R}✗${N} ${W}Config no encontrado${N}"
    pause
    return
  fi

  local current
  current="$(jq -r '.inbounds[0].streamSettings.wsSettings.headers.Host // "sin host"' "$config" 2>/dev/null)"
  echo ""
  echo -e "  ${W}Host actual:${N} ${Y}${current}${N}"
  sep

  echo -ne "  ${W}Nuevo host: ${G}"
  read -r new_host
  echo -ne "${N}"
  [[ -z "$new_host" || "$new_host" == "0" ]] && return

  local temp
  temp=$(mktemp)
  jq --arg a "$new_host" '.inbounds[0].streamSettings.wsSettings.headers.Host = $a' "$config" > "$temp" && mv "$temp" "$config"
  chmod 644 "$config"

  echo ""
  v2ray_restart

  echo ""
  echo -e "  ${G}✓${N} ${W}Host cambiado a ${Y}${new_host}${N}"
  pause
}

# =========================================================
#  CONFIGURAR PATH
# =========================================================
config_path() {
  clear
  hr
  echo -e "${W}${BOLD}          CONFIGURAR PATH${N}"
  hr

  if ! config_exists; then
    echo -e "  ${R}✗${N} ${W}Config no encontrado${N}"
    pause
    return
  fi

  local current
  current="$(jq -r '.inbounds[0].streamSettings.wsSettings.path // "/"' "$config" 2>/dev/null)"
  echo ""
  echo -e "  ${W}Path actual:${N} ${Y}${current}${N}"
  sep

  echo -ne "  ${W}Nuevo path: ${G}"
  read -r new_path
  echo -ne "${N}"
  [[ -z "$new_path" || "$new_path" == "0" ]] && return

  local temp
  temp=$(mktemp)
  jq --arg a "$new_path" '.inbounds[0].streamSettings.wsSettings.path = $a' "$config" > "$temp" && mv "$temp" "$config"
  chmod 644 "$config"

  echo ""
  v2ray_restart

  echo ""
  echo -e "  ${G}✓${N} ${W}Path cambiado a ${Y}${new_path}${N}"
  pause
}

# =========================================================
#  CERTIFICADO SSL/TLS
# =========================================================
config_tls() {
  clear
  hr
  echo -e "${W}${BOLD}          CERTIFICADO SSL/TLS${N}"
  hr

  if ! config_exists; then
    echo -e "  ${R}✗${N} ${W}Config no encontrado${N}"
    pause
    return
  fi

  local current_tls
  current_tls="$(get_tls)"
  echo ""
  echo -e "  ${W}TLS actual:${N} ${Y}${current_tls}${N}"
  sep

  # Buscar certificados existentes
  local db cert key domi
  db="$(ls "$VPS_crt" 2>/dev/null || true)"
  cert="$(echo "$db" | grep '\.crt$' 2>/dev/null || true)"
  key="$(echo "$db" | grep '\.key$' 2>/dev/null || true)"

  if [[ -n "$cert" && -n "$key" ]]; then
    domi="$(cat "${SN_DIR}/dominio.txt" 2>/dev/null || echo 'N/A')"
    echo ""
    echo -e "  ${G}✓${N} ${W}Certificado encontrado:${N}"
    echo -e "    ${W}Dominio:${N} ${Y}${domi}${N}"
    echo -e "    ${W}CERT:${N}    ${C}${cert}${N}"
    echo -e "    ${W}KEY:${N}     ${C}${key}${N}"
    sep
    echo -ne "  ${W}¿Usar este certificado? (s/n): ${G}"
    read -r use_cert
    echo -ne "${N}"

    if [[ "${use_cert,,}" == "s" ]]; then
      local temp
      temp=$(mktemp)
      jq --arg cert "${VPS_crt}/${cert}" --arg key "${VPS_crt}/${key}" \
        '.inbounds[0].streamSettings.tlsSettings = {"certificates":[{"certificateFile":$cert,"keyFile":$key}]}' \
        "$config" > "$temp"

      if [[ -n "$domi" && "$domi" != "N/A" ]]; then
        jq --arg d "$domi" '.inbounds[0].domain = $d' "$temp" > "${temp}.2" && mv "${temp}.2" "$temp"
      fi

      jq '.inbounds[0].streamSettings.security = "tls"' "$temp" > "${temp}.2" && mv "${temp}.2" "$config"
      chmod 644 "$config"
      rm -f "$temp"

      echo ""
      v2ray_restart
      echo ""
      echo -e "  ${G}✓${N} ${W}TLS configurado con certificado existente${N}"
      pause
      return
    fi
  fi

  # Usar v2ray tls nativo
  echo ""
  echo -e "  ${W}Ejecutando configuración TLS nativa...${N}"
  sep
  if command -v v2ray >/dev/null 2>&1; then
    echo -e "\033[1;37m"
    v2ray tls
  else
    echo -e "  ${R}✗${N} ${W}Comando v2ray no disponible${N}"
  fi

  pause
}

# =========================================================
#  PROTOCOLOS V2RAY (stream)
# =========================================================
config_stream() {
  clear
  hr
  echo -e "${W}${BOLD}          PROTOCOLOS V2RAY${N}"
  hr

  if ! command -v v2ray >/dev/null 2>&1; then
    echo -e "  ${R}✗${N} ${W}Comando v2ray no disponible${N}"
    pause
    return
  fi

  echo ""
  echo -e "\033[1;37m"
  v2ray stream
  hr
  pause
}

# =========================================================
#  CONFIGURACIÓN NATIVA
# =========================================================
config_native() {
  clear
  hr
  echo -e "${W}${BOLD}          CONFIGURACIÓN NATIVA V2RAY${N}"
  hr

  if ! command -v v2ray >/dev/null 2>&1; then
    echo -e "  ${R}✗${N} ${W}Comando v2ray no disponible${N}"
    pause
    return
  fi

  echo -ne "\033[1;37m"
  v2ray
}

# =========================================================
#  RESTABLECER AJUSTES
# =========================================================
reset_config() {
  clear
  hr
  echo -e "${W}${BOLD}          RESTABLECER AJUSTES V2RAY${N}"
  hr

  if ! config_exists; then
    echo -e "  ${R}✗${N} ${W}Config no encontrado${N}"
    pause
    return
  fi

  echo ""
  echo -e "  ${Y}⚠ Esto restablecerá la configuración de V2Ray${N}"
  echo -e "  ${W}  Los usuarios se mantendrán${N}"
  echo ""
  echo -ne "  ${W}¿Continuar? (s/n): ${G}"
  read -r confirm
  echo -ne "${N}"
  [[ "${confirm,,}" == "s" ]] || { echo -e "  ${Y}Cancelado${N}"; pause; return; }

  echo ""

  # Guardar usuarios
  local users_backup
  users_backup="$(jq -c '.inbounds[0].settings.clients' "$config" 2>/dev/null || echo '[]')"

  progress_bar "Restableciendo configuración" 2

  # Crear nueva config
  if command -v v2ray >/dev/null 2>&1; then
    v2ray new >/dev/null 2>&1 || true
  fi

  if config_exists; then
    local temp
    temp=$(mktemp)

    # Limpiar KCP y configurar WS
    jq 'del(.inbounds[0].streamSettings.kcpSettings)' "$config" > "$temp"
    jq '.inbounds[0].streamSettings += {"network":"ws","wsSettings":{"path":"/VPS-SN/","headers":{"Host":"ejemplo.com"}}}' "$temp" > "$config"
    chmod 644 "$config"
    rm -f "$temp"

    # Restaurar usuarios
    if [[ -n "$users_backup" && "$users_backup" != "[]" && "$users_backup" != "null" ]]; then
      progress_bar "Restaurando usuarios" 1
      temp=$(mktemp)
      jq --argjson u "$users_backup" '.inbounds[0].settings.clients = $u' "$config" > "$temp" && mv "$temp" "$config"
      chmod 644 "$config"
    fi
  fi

  echo ""
  v2ray_restart

  echo ""
  echo -e "  ${G}✓${N} ${W}Configuración restablecida${N}"
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
      systemctl stop v2ray >/dev/null 2>&1 || true
      sleep 0.5
    ) &
    spinner $! "Deteniendo V2Ray..."
    echo -e "  ${Y}■ Servicio detenido${N}"
  else
    (
      systemctl start v2ray >/dev/null 2>&1 || true
      sleep 1
    ) &
    spinner $! "Iniciando V2Ray..."

    if is_running; then
      echo -e "  ${G}${BOLD}✓ Servicio iniciado${N}"
    else
      echo -e "  ${R}✗ Fallo al iniciar${N}"
    fi
  fi

  hr
  pause
}

# =========================================================
#  MENÚ PRINCIPAL
# =========================================================
main_menu() {
  require_root

  while true; do
    clear

    hr
    echo -e "${W}${BOLD}              V2RAY MANAGER BY @SIN_NOMBRE22${N}"
    hr

    if is_installed && config_exists; then
      echo -e "  ${W}ESTADO:${N}      $(status_badge)"
      echo -e "  ${W}PUERTO:${N}      ${Y}$(get_port)${N}"
      echo -e "  ${W}PROTOCOLO:${N}   ${C}$(get_protocol)${N}"
      echo -e "  ${W}NETWORK:${N}     ${C}$(get_network)${N}"
      echo -e "  ${W}TLS:${N}         ${Y}$(get_tls)${N}"
      echo -e "  ${W}USUARIOS:${N}    ${C}$(get_users_count)${N}"
      hr
      echo ""
      echo -e "  ${W}${BOLD}INSTALACIÓN${N}"
      sep
      echo -e "  ${G}[${W}1${G}]${N}  ${C}Instalar / Reinstalar V2Ray${N}"
      echo -e "  ${G}[${W}2${G}]${N}  ${R}Desinstalar V2Ray${N}"
      sep
      echo -e "  ${W}${BOLD}CONFIGURACIÓN BÁSICA${N}"
      sep
      echo -e "  ${G}[${W}3${G}]${N}  ${C}Configurar Puerto${N}"
      echo -e "  ${G}[${W}4${G}]${N}  ${C}Configurar AlterId${N}"
      echo -e "  ${G}[${W}5${G}]${N}  ${C}Configurar Address${N}"
      echo -e "  ${G}[${W}6${G}]${N}  ${C}Configurar Host${N}"
      echo -e "  ${G}[${W}7${G}]${N}  ${C}Configurar Path${N}"
      sep
      echo -e "  ${W}${BOLD}CONFIGURACIÓN AVANZADA${N}"
      sep
      echo -e "  ${G}[${W}8${G}]${N}  ${C}Certificado SSL/TLS${N}"
      echo -e "  ${G}[${W}9${G}]${N}  ${C}Protocolos V2Ray${N}"
      echo -e "  ${G}[${W}10${G}]${N} ${C}Configuración Nativa${N}"
      echo -e "  ${G}[${W}11${G}]${N} ${C}Restablecer Ajustes${N}"
      sep
      echo -e "  ${G}[${W}12${G}]${N} ${C}Iniciar / Parar${N}  $(status_badge)"
      hr
      echo -e "  ${G}[${W}0${G}]${N}  ${W}Volver${N}"
      hr
      echo ""
      echo -ne "  ${W}Opción: ${G}"
      read -r op
      echo -ne "${N}"

      case "${op:-}" in
        1)  install_v2ray ;;
        2)  uninstall_v2ray ;;
        3)  config_port ;;
        4)  config_alterid ;;
        5)  config_address ;;
        6)  config_host ;;
        7)  config_path ;;
        8)  config_tls ;;
        9)  config_stream ;;
        10) config_native ;;
        11) reset_config ;;
        12) toggle_service ;;
        0)  break ;;
        *)  echo -e "  ${R}Opción inválida${N}"; sleep 1 ;;
      esac
    else
      echo -e "  ${W}ESTADO:${N}  ${R}${BOLD}● NO INSTALADO${N}"
      hr
      echo ""
      echo -e "  ${G}[${W}1${G}]${N}  ${C}Instalar V2Ray${N}"
      hr
      echo -e "  ${G}[${W}0${G}]${N}  ${W}Volver${N}"
      hr
      echo ""
      echo -ne "  ${W}Opción: ${G}"
      read -r op
      echo -ne "${N}"

      case "${op:-}" in
        1) install_v2ray ;;
        0) break ;;
        *) echo -e "  ${R}Opción inválida${N}"; sleep 1 ;;
      esac
    fi
  done
}

trap 'echo -ne "${N}"; tput cnorm 2>/dev/null; exit 0' SIGINT SIGTERM

main_menu
