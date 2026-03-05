#!/bin/bash
# =========================================================
# SinNombre v2.0 - ADMINISTRADOR DROPBEAR
# Archivo: SN/Protocolos/dropbear.sh
#
# CAMBIOS v2.0 (2026-03-05):
# - Usa lib/colores.sh (sin colores duplicados)
# - Barra de progreso fina animada (━╸) estilo profesional
# - Spinner para procesos en background
# - Desinstalación real (purge + eliminar configs/keys/logs)
# - Corrección de errores: color reset, validaciones, trap
# =========================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── Cargar colores desde lib ────────────────────────────
LIB_COLORES="$ROOT_DIR/lib/colores.sh"
if [[ -f "$LIB_COLORES" ]]; then
  source "$LIB_COLORES"
else
  R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; B='\033[0;34m'
  M='\033[0;35m'; C='\033[0;36m'; W='\033[1;37m'; N='\033[0m'
  D='\033[2m'; BOLD='\033[1m'
  hr()  { echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"; }
  sep() { echo -e "${R}──────────────────────────────────────────────────────────${N}"; }
  pause(){ echo ""; read -r -p "Presiona Enter para continuar..."; }
fi

# ── Rutas de configuración ──────────────────────────────
DROPBEAR_CONF="/etc/default/dropbear"
DROPBEAR_BIN="/usr/sbin/dropbear"
DROPBEAR_KEYS="/etc/dropbear"

# =========================================================
#  ANIMACIONES PROFESIONALES
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

show_header() {
  clear
  hr
  echo -e "${W}${BOLD}         ADMINISTRADOR DROPBEAR SSH${N}"
  hr
}

is_installed() {
  command -v dropbear >/dev/null 2>&1 || [[ -f "$DROPBEAR_BIN" ]]
}

get_ports() {
  local ports=""
  ports=$(ss -H -lntp 2>/dev/null \
    | awk '/dropbear/ {print $4}' \
    | awk -F: '{print $NF}' \
    | sort -nu | tr '\n' ',' | sed 's/,$//') || true

  if [[ -z "$ports" ]] && [[ -f "$DROPBEAR_CONF" ]]; then
    ports=$(grep -oP 'DROPBEAR_PORT=\K[0-9]+' "$DROPBEAR_CONF" 2>/dev/null || true)
  fi

  [[ -n "${ports//,/}" ]] && echo "$ports" || echo ""
}

is_running() {
  pgrep -x dropbear >/dev/null 2>&1
}

# =========================================================
#  INSTALAR DROPBEAR
# =========================================================
install_dropbear_custom() {
  show_header
  echo -e "  ${W}${BOLD}INSTALAR DROPBEAR${N}"
  hr

  if is_installed; then
    echo -e "  ${Y}⚠${N} ${W}Dropbear ya está instalado${N}"
    pause
    return 0
  fi

  echo ""
  local port=""
  while [[ -z "$port" ]]; do
    echo -ne "  ${W}Ingresa el puerto para Dropbear [1-65535]: ${G}"
    read -r port
    echo -ne "${N}"
    if [[ ! "$port" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
      echo -e "  ${R}✗${N} ${W}Puerto inválido (rango: 1-65535)${N}"
      port=""
    fi
  done

  # Verificar si el puerto ya está en uso
  if ss -H -lnt 2>/dev/null | awk '{print $4}' | awk -F: '{print $NF}' | grep -qx "$port"; then
    echo -e "  ${R}✗${N} ${W}Puerto ${Y}${port}${W} ya está en uso${N}"
    echo -ne "  ${W}¿Continuar de todas formas? (s/n): ${G}"
    read -r force
    echo -ne "${N}"
    [[ "${force,,}" == "s" ]] || { pause; return 0; }
  fi

  echo ""
  sep

  # Paso 1: Actualizar repos
  (
    apt-get update -y >/dev/null 2>&1 || true
  ) &
  spinner $! "Actualizando repositorios..."

  # Paso 2: Instalar paquete
  progress_bar "Instalando Dropbear" 3
  apt-get install -y dropbear >/dev/null 2>&1 || {
    echo -e "  ${R}✗${N} ${W}Error al instalar dropbear${N}"
    pause
    return 1
  }

  # Paso 3: Crear directorio de claves
  mkdir -p "$DROPBEAR_KEYS" 2>/dev/null || true

  # Paso 4: Escribir configuración
  progress_bar "Escribiendo configuración" 1
  cat > "$DROPBEAR_CONF" << EOF
# Configuración Dropbear - SinNombre SSH
NO_START=0
DROPBEAR_PORT=$port
DROPBEAR_EXTRA_ARGS="-p $port -K 300 -t 600"
DROPBEAR_BANNER=""
EOF

  # Paso 5: Generar claves RSA
  if [[ ! -f "${DROPBEAR_KEYS}/dropbear_rsa_host_key" ]]; then
    (
      dropbearkey -t rsa -f "${DROPBEAR_KEYS}/dropbear_rsa_host_key" -s 2048 >/dev/null 2>&1 || {
        ssh-keygen -t rsa -f "${DROPBEAR_KEYS}/dropbear_rsa_host_key" -N '' >/dev/null 2>&1 || true
      }
    ) &
    spinner $! "Generando claves RSA (2048 bits)..."
  fi

  # Paso 6: Habilitar e iniciar servicio
  (
    systemctl enable dropbear >/dev/null 2>&1 || true
    systemctl restart dropbear >/dev/null 2>&1 || {
      pkill dropbear 2>/dev/null || true
      dropbear -p "$port" -R -E >/dev/null 2>&1 &
    }
    sleep 1
  ) &
  spinner $! "Iniciando servicio Dropbear..."

  echo ""
  hr
  echo -e "  ${G}${BOLD}✓ DROPBEAR INSTALADO CON ÉXITO${N}"
  hr
  echo ""
  echo -e "  ${W}Puerto:${N}          ${G}${port}${N}"
  echo -e "  ${W}Configuración:${N}   ${C}${DROPBEAR_CONF}${N}"
  echo -e "  ${W}Claves:${N}          ${C}${DROPBEAR_KEYS}/${N}"
  echo -e "  ${W}Protocolo:${N}       ${Y}SSH-2.0-dropbear${N}"
  echo ""
  hr
  pause
  return 0
}

# =========================================================
#  CONFIGURAR PUERTO
# =========================================================
set_port_custom() {
  show_header
  echo -e "  ${W}${BOLD}CONFIGURAR PUERTO DROPBEAR${N}"
  hr

  local current_ports
  current_ports=$(get_ports)
  echo ""
  echo -e "  ${W}Puerto(s) actual(es):${N} ${Y}${current_ports:-Ninguno}${N}"
  sep

  local new_port=""
  while [[ -z "$new_port" ]]; do
    echo -ne "  ${W}Ingresa el nuevo puerto [1-65535]: ${G}"
    read -r new_port
    echo -ne "${N}"
    if [[ ! "$new_port" =~ ^[0-9]+$ ]] || (( new_port < 1 || new_port > 65535 )); then
      echo -e "  ${R}✗${N} ${W}Puerto inválido${N}"
      new_port=""
    fi
  done

  echo ""

  # Detener servicio actual
  (
    pkill dropbear 2>/dev/null || true
    systemctl stop dropbear 2>/dev/null || true
    sleep 0.3
  ) &
  spinner $! "Deteniendo servicio actual..."

  # Actualizar configuración
  progress_bar "Actualizando configuración" 1
  cat > "$DROPBEAR_CONF" << EOF
# Configuración Dropbear - SinNombre SSH
NO_START=0
DROPBEAR_PORT=$new_port
DROPBEAR_EXTRA_ARGS="-p $new_port -K 300 -t 600"
DROPBEAR_BANNER=""
EOF

  # Reiniciar servicio
  (
    systemctl restart dropbear >/dev/null 2>&1 || {
      dropbear -p "$new_port" -R -E >/dev/null 2>&1 &
    }
    sleep 1
  ) &
  spinner $! "Reiniciando con puerto $new_port..."

  echo ""
  hr
  echo -e "  ${G}${BOLD}✓ Puerto configurado: ${Y}${new_port}${N}"
  hr
  pause
  return 0
}

# =========================================================
#  REINICIAR SERVICIO
# =========================================================
restart_service() {
  show_header
  echo ""

  (
    pkill dropbear 2>/dev/null || true
    systemctl restart dropbear >/dev/null 2>&1 || {
      dropbear -R -E >/dev/null 2>&1 &
    }
    sleep 1
  ) &
  spinner $! "Reiniciando servicio Dropbear..."

  if is_running; then
    echo -e "  ${G}${BOLD}✓ Servicio Dropbear reiniciado${N}"
  else
    echo -e "  ${R}✗ Falla al reiniciar Dropbear${N}"
  fi

  hr
  pause
  return 0
}

# =========================================================
#  DESINSTALAR DROPBEAR
# =========================================================
uninstall_dropbear_custom() {
  show_header
  echo -e "  ${W}${BOLD}DESINSTALAR DROPBEAR${N}"
  hr

  if ! is_installed; then
    echo -e "  ${Y}⚠${N} ${W}Dropbear no está instalado${N}"
    pause
    return 0
  fi

  echo ""
  echo -e "  ${Y}⚠ Se eliminará completamente:${N}"
  echo -e "    ${W}•${N} Paquete dropbear"
  echo -e "    ${W}•${N} Claves SSH ${C}${DROPBEAR_KEYS}/${N}"
  echo -e "    ${W}•${N} Configuración ${C}${DROPBEAR_CONF}${N}"
  echo -e "    ${W}•${N} Logs del servicio"
  echo ""
  echo -ne "  ${W}¿Estás seguro? (s/n): ${G}"
  read -r confirm
  echo -ne "${N}"

  if [[ "${confirm,,}" != "s" ]]; then
    echo -e "  ${Y}Cancelado${N}"
    pause
    return 0
  fi

  echo ""
  sep

  # Paso 1: Detener servicio
  (
    pkill dropbear 2>/dev/null || true
    systemctl stop dropbear 2>/dev/null || true
    systemctl disable dropbear 2>/dev/null || true
    sleep 0.5
  ) &
  spinner $! "Deteniendo servicio Dropbear..."

  # Paso 2: Purgar paquete
  progress_bar "Eliminando paquete" 3
  apt-get purge -y dropbear dropbear-bin dropbear-run 2>/dev/null || true
  apt-get purge -y 'dropbear*' >/dev/null 2>&1 || true
  apt-get autoremove -y >/dev/null 2>&1 || true

  # Paso 3: Eliminar configuración y claves
  progress_bar "Limpiando configuración" 2
  rm -rf "$DROPBEAR_KEYS" >/dev/null 2>&1 || true
  rm -f /etc/default/dropbear* >/dev/null 2>&1 || true

  # Paso 4: Limpiar logs y restos
  (
    journalctl --rotate >/dev/null 2>&1 || true
    journalctl --vacuum-time=1s --unit=dropbear >/dev/null 2>&1 || true
    systemctl daemon-reload >/dev/null 2>&1 || true
    sleep 0.3
  ) &
  spinner $! "Limpiando logs y restos..."

  echo ""
  hr
  echo -e "  ${G}${BOLD}✓ DROPBEAR DESINSTALADO COMPLETAMENTE${N}"
  hr
  echo ""
  sleep 1
  pause
  return 0
}

# =========================================================
#  VER PUERTOS ACTIVOS
# =========================================================
list_ports_menu() {
  show_header
  echo -e "  ${W}${BOLD}PUERTOS DROPBEAR ACTIVOS${N}"
  hr

  local ports
  ports=$(get_ports)

  if [[ -z "$ports" ]]; then
    echo ""
    echo -e "  ${Y}⚠${N} ${W}No hay puertos Dropbear activos${N}"
    echo ""
    if is_running; then
      echo -e "  ${D}Dropbear está corriendo pero no se detectaron puertos${N}"
    else
      echo -e "  ${D}Dropbear no está corriendo${N}"
    fi
  else
    local -a arr_ports
    IFS=',' read -ra arr_ports <<< "$ports"
    echo ""
    local i=1
    for port in "${arr_ports[@]}"; do
      echo -e "  ${G}[${W}${i}${G}]${N} ${W}▸${N} Puerto ${Y}${port}${N}"
      ((i++))
    done
  fi

  echo ""

  # Mostrar estado del proceso
  sep
  if is_running; then
    local pid_count
    pid_count="$(pgrep -cx dropbear 2>/dev/null || echo "0")"
    echo -e "  ${W}Estado:${N}    ${G}${BOLD}● Corriendo${N}  ${D}(${pid_count} procesos)${N}"
  else
    echo -e "  ${W}Estado:${N}    ${R}${BOLD}● Detenido${N}"
  fi
  sep

  pause
  return 0
}

# =========================================================
#  VER LOGS
# =========================================================
show_log() {
  show_header
  echo -e "  ${W}${BOLD}LOGS DE DROPBEAR${N} ${D}(últimas 20 líneas)${N}"
  hr
  echo ""

  local log_output
  log_output="$(journalctl -u dropbear --no-pager -n 20 2>/dev/null || true)"

  if [[ -n "$log_output" ]]; then
    echo -e "${D}${log_output}${N}"
  else
    echo -e "  ${Y}⚠${N} ${W}No hay logs disponibles${N}"
    echo -e "  ${D}SSH-2.0-dropbear (sin registros recientes)${N}"
  fi

  echo ""
  hr
  pause
  return 0
}

# =========================================================
#  MENÚ PRINCIPAL
# =========================================================
main_menu() {
  require_root

  while true; do
    show_header

    local ports st
    ports=$(get_ports)

    if ! is_installed; then
      # ── Menú: NO instalado ──────────────────────────
      echo ""
      echo -e "  ${W}Estado:${N} ${R}${BOLD}● NO INSTALADO${N}"
      hr
      echo ""
      echo -e "  ${G}[${W}1${G}]${N}  ${C}Instalar Dropbear${N}"
      hr
      echo -e "  ${G}[${W}0${G}]${N}  ${W}Volver${N}"
      hr
      echo ""
      echo -ne "  ${W}Opción: ${G}"
      read -r opt
      echo -ne "${N}"

      case "${opt:-}" in
        1) install_dropbear_custom ;;
        0) break ;;
        *) echo -e "  ${R}Opción inválida${N}"; sleep 1 ;;
      esac
      continue
    fi

    # ── Menú: Instalado ────────────────────────────────
    if is_running; then
      st="${G}${BOLD}● ON${N}"
    else
      st="${R}${BOLD}● OFF${N}"
    fi

    echo ""
    echo -e "  ${W}ESTADO:${N}    ${st}"
    echo -e "  ${W}PUERTOS:${N}   ${Y}${ports:-Ninguno}${N}"
    hr
    echo ""
    echo -e "  ${G}[${W}1${G}]${N}  ${C}Reiniciar servicio${N}"
    echo -e "  ${G}[${W}2${G}]${N}  ${C}Configurar puerto${N}"
    echo -e "  ${G}[${W}3${G}]${N}  ${C}Ver puertos activos${N}"
    echo -e "  ${G}[${W}4${G}]${N}  ${C}Ver logs${N}"
    sep
    echo -e "  ${G}[${W}5${G}]${N}  ${C}Instalar / Reinstalar${N}"
    echo -e "  ${G}[${W}6${G}]${N}  ${R}Desinstalar Dropbear${N}"
    hr
    echo -e "  ${G}[${W}0${G}]${N}  ${W}Volver${N}"
    hr
    echo ""
    echo -ne "  ${W}Opción: ${G}"
    read -r opt
    echo -ne "${N}"

    case "${opt:-}" in
      1) restart_service ;;
      2) set_port_custom ;;
      3) list_ports_menu ;;
      4) show_log ;;
      5) install_dropbear_custom ;;
      6) uninstall_dropbear_custom ;;
      0) break ;;
      *) echo -e "  ${R}Opción inválida${N}"; sleep 1 ;;
    esac
  done
}

# ── Manejo de señales (salir limpio) ────────────────────
trap 'echo -ne "${N}"; tput cnorm 2>/dev/null; exit 0' SIGINT SIGTERM

# ── Soporte para argumentos de línea de comandos ────────
case "${1:-}" in
  "--install"|"-i")   require_root; install_dropbear_custom ;;
  "--set-port"|"-p")  require_root; set_port_custom ;;
  "--restart"|"-r")   require_root; restart_service ;;
  "--uninstall"|"-u") require_root; uninstall_dropbear_custom ;;
  "--ports"|"-pt")    require_root; list_ports_menu ;;
  "--log"|"-l")       require_root; show_log ;;
  *)                  main_menu ;;
esac
