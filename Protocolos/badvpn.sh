#!/bin/bash
# =========================================================
# SinNombre v2.0 - BADVPN-UDPGW
# Archivo: SN/Protocolos/badvpn.sh
#
# CAMBIOS v2.0 (2026-03-05):
# - Usa lib/colores.sh (sin colores duplicados)
# - Barra de progreso fina (━╸) + spinner profesional
# - Desinstalación real y completa
# - Menú simplificado con estado en header
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
BIN="/usr/bin/badvpn-udpgw"
SVC="/etc/systemd/system/badvpn.service"
LOCK="/root/udp-SN"

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

is_installed() {
  [[ -x "$BIN" ]]
}

is_on() {
  systemctl is-active --quiet badvpn 2>/dev/null && return 0
  pgrep -x badvpn-udpgw >/dev/null 2>&1 && return 0
  return 1
}

status_badge() {
  if is_on; then
    echo -e "${G}${BOLD}● ON${N}"
  else
    echo -e "${R}${BOLD}● OFF${N}"
  fi
}

get_listen_info() {
  if [[ -f "$SVC" ]]; then
    grep -oP 'listen-addr \K[^\s]+' "$SVC" 2>/dev/null || echo "No configurado"
  else
    echo "No configurado"
  fi
}

# =========================================================
#  INSTALAR BADVPN
# =========================================================
install_badvpn() {
  clear
  hr
  echo -e "${W}${BOLD}          INSTALAR BADVPN-UDPGW${N}"
  hr

  if is_installed; then
    echo ""
    echo -e "  ${Y}⚠${N} ${W}Ya está instalado:${N} ${C}${BIN}${N}"
    pause
    return
  fi

  echo ""

  # Paso 1: Dependencias
  (
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y wget unzip cmake make gcc g++ build-essential lsof >/dev/null 2>&1 || true
  ) &
  spinner $! "Instalando dependencias de compilación..."

  # Limpiar rastros viejos
  if [[ ! -e "$LOCK" ]]; then
    rm -f /usr/bin/badvpn-udpgw /bin/badvpn-udpgw >/dev/null 2>&1 || true
    touch "$LOCK" >/dev/null 2>&1 || true
  fi

  # Paso 2: Descargar
  cd /root
  rm -rf /root/badvpn-master /root/badvpn-master.zip >/dev/null 2>&1 || true

  (
    wget -qO /root/badvpn-master.zip \
      "https://github.com/NetVPS/Multi-Script/raw/main/R9/Utils/badvpn/badvpn-master.zip" 2>/dev/null
  ) &
  spinner $! "Descargando badvpn-master.zip..."

  if [[ ! -f /root/badvpn-master.zip ]]; then
    echo -e "  ${R}✗${N} ${W}Fallo la descarga${N}"
    pause
    return
  fi

  # Paso 3: Descomprimir
  (
    unzip -oq /root/badvpn-master.zip -d /root 2>/dev/null
  ) &
  spinner $! "Descomprimiendo..."

  if [[ ! -d /root/badvpn-master ]]; then
    echo -e "  ${R}✗${N} ${W}Fallo al descomprimir${N}"
    pause
    return
  fi

  # Paso 4: Compilar
  cd /root/badvpn-master
  mkdir -p build
  cd build

  progress_bar "Ejecutando cmake" 3
  cmake .. -DCMAKE_INSTALL_PREFIX="/" -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1 >/dev/null 2>&1 || {
    echo -e "  ${R}✗${N} ${W}Fallo cmake${N}"
    pause
    return
  }

  progress_bar "Compilando (make install)" 5
  make install >/dev/null 2>&1 || {
    echo -e "  ${R}✗${N} ${W}Fallo make install${N}"
    pause
    return
  }

  # Paso 5: Limpiar fuentes
  (
    rm -rf /root/badvpn-master /root/badvpn-master.zip >/dev/null 2>&1 || true
  ) &
  spinner $! "Limpiando archivos temporales..."

  echo ""
  hr
  echo -e "  ${G}${BOLD}✓ BADVPN INSTALADO${N}"
  hr
  echo ""
  echo -e "  ${W}Binario:${N} ${C}${BIN}${N}"
  echo ""
  hr

  # Ir directo a configurar
  echo ""
  echo -ne "  ${W}¿Configurar e iniciar ahora? (s/n): ${G}"
  read -r auto_conf
  echo -ne "${N}"
  [[ "${auto_conf,,}" == "s" ]] && configure_and_start

  pause
}

# =========================================================
#  CONFIGURAR + INICIAR
# =========================================================
configure_and_start() {
  clear
  hr
  echo -e "${W}${BOLD}          CONFIGURAR BADVPN-UDPGW${N}"
  hr

  if ! is_installed; then
    echo -e "  ${R}✗${N} ${W}No está instalado. Instala primero.${N}"
    pause
    return
  fi

  echo ""
  echo -e "  ${D}Presiona Enter en cada campo para usar el valor por defecto${N}"
  echo ""

  # IP
  echo -ne "  ${W}IP listen [${D}127.0.0.1${W}]: ${G}"
  read -r ip
  echo -ne "${N}"
  ip="${ip:-127.0.0.1}"

  # Puerto
  local port=""
  while true; do
    echo -ne "  ${W}Puerto [${D}7300${W}]: ${G}"
    read -r port
    echo -ne "${N}"
    port="${port:-7300}"
    if [[ "$port" =~ ^[0-9]+$ ]] && (( port >= 1 && port <= 65535 )); then
      break
    fi
    echo -e "  ${R}✗${N} ${W}Puerto inválido (1-65535)${N}"
  done

  # Max clients
  echo -ne "  ${W}Max clientes [${D}2000${W}]: ${G}"
  read -r max_clients
  echo -ne "${N}"
  max_clients="${max_clients:-2000}"
  [[ "$max_clients" =~ ^[0-9]+$ ]] || max_clients="2000"

  # Max conexiones
  echo -ne "  ${W}Max conexiones por cliente [${D}100${W}]: ${G}"
  read -r max_conn
  echo -ne "${N}"
  max_conn="${max_conn:-100}"
  [[ "$max_conn" =~ ^[0-9]+$ ]] || max_conn="100"

  # Resumen
  echo ""
  sep
  echo -e "  ${W}${BOLD}RESUMEN:${N}"
  echo -e "    ${W}Escucha:${N}       ${Y}${ip}:${port}${N}"
  echo -e "    ${W}Max clientes:${N}  ${C}${max_clients}${N}"
  echo -e "    ${W}Max conn/cli:${N}  ${C}${max_conn}${N}"
  sep
  echo -ne "  ${W}¿Aplicar? (s/n): ${G}"
  read -r confirm
  echo -ne "${N}"
  [[ "${confirm,,}" == "s" ]] || { echo -e "  ${Y}Cancelado${N}"; pause; return; }

  echo ""

  # Crear servicio
  progress_bar "Creando servicio systemd" 2
  cat > "$SVC" <<EOF
[Unit]
Description=BadVPN UDPGW Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root
ExecStart=${BIN} --listen-addr ${ip}:${port} --max-clients ${max_clients} --max-connections-for-client ${max_conn} --client-socket-sndbuf 1048576 --udp-mtu 9000
Restart=always
RestartSec=3s

[Install]
WantedBy=multi-user.target
EOF

  # Iniciar
  (
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl enable badvpn >/dev/null 2>&1 || true
    systemctl restart badvpn >/dev/null 2>&1 || true
    sleep 1
  ) &
  spinner $! "Iniciando servicio badvpn..."

  echo ""
  hr
  if is_on; then
    echo -e "  ${G}${BOLD}✓ BADVPN CONFIGURADO Y ACTIVO${N}"
    hr
    echo ""
    echo -e "  ${W}Escucha:${N}   ${Y}${ip}:${port}${N}"
    echo -e "  ${W}Estado:${N}    $(status_badge)"
  else
    echo -e "  ${R}✗ Fallo al iniciar badvpn${N}"
    hr
    echo ""
    echo -e "  ${D}Revisa los logs con la opción del menú${N}"
  fi
  echo ""
  hr
  pause
}

# =========================================================
#  INICIAR / PARAR
# =========================================================
start_stop() {
  clear
  hr

  if is_on; then
    (
      systemctl stop badvpn >/dev/null 2>&1 || true
      sleep 0.5
    ) &
    spinner $! "Deteniendo badvpn..."
    echo -e "  ${Y}■ Servicio detenido${N}"
  else
    (
      systemctl start badvpn >/dev/null 2>&1 || true
      sleep 1
    ) &
    spinner $! "Iniciando badvpn..."

    if is_on; then
      echo -e "  ${G}${BOLD}✓ Servicio iniciado${N}"
    else
      echo -e "  ${R}✗ Fallo al iniciar${N}"
    fi
  fi

  hr
  pause
}

# =========================================================
#  REINICIAR
# =========================================================
restart_srv() {
  clear
  hr

  (
    systemctl restart badvpn >/dev/null 2>&1 || true
    sleep 1
  ) &
  spinner $! "Reiniciando badvpn..."

  if is_on; then
    echo -e "  ${G}${BOLD}✓ Servicio reiniciado${N}"
  else
    echo -e "  ${R}✗ Fallo al reiniciar${N}"
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
  echo -e "  ${W}${BOLD}LOGS BADVPN${N} ${D}(últimas 30 líneas)${N}"
  hr
  echo ""

  local log_output
  log_output="$(journalctl -u badvpn -n 30 --no-pager 2>/dev/null || true)"

  if [[ -n "$log_output" ]]; then
    echo -e "${D}${log_output}${N}"
  else
    echo -e "  ${Y}⚠${N} ${W}No hay logs disponibles${N}"
  fi

  echo ""
  hr
  pause
}

# =========================================================
#  DESINSTALAR
# =========================================================
uninstall_all() {
  clear
  hr
  echo -e "${W}${BOLD}          DESINSTALAR BADVPN${N}"
  hr

  if ! is_installed && [[ ! -f "$SVC" ]]; then
    echo -e "  ${Y}⚠${N} ${W}BadVPN no está instalado${N}"
    pause
    return
  fi

  echo ""
  echo -e "  ${Y}⚠ Se eliminará completamente:${N}"
  echo -e "    ${W}•${N} Binario ${C}${BIN}${N}"
  echo -e "    ${W}•${N} Servicio systemd ${C}badvpn${N}"
  echo -e "    ${W}•${N} Archivo lock"
  echo ""
  echo -ne "  ${W}¿Estás seguro? (s/n): ${G}"
  read -r yn
  echo -ne "${N}"
  [[ "${yn,,}" == "s" ]] || { echo -e "  ${Y}Cancelado${N}"; pause; return; }

  echo ""
  sep

  (
    systemctl stop badvpn >/dev/null 2>&1 || true
    systemctl disable badvpn >/dev/null 2>&1 || true
    sleep 0.5
  ) &
  spinner $! "Deteniendo servicio..."

  progress_bar "Eliminando archivos" 2
  rm -f "$SVC" >/dev/null 2>&1 || true
  rm -f "$BIN" /bin/badvpn-udpgw >/dev/null 2>&1 || true
  rm -f "$LOCK" >/dev/null 2>&1 || true

  (
    systemctl daemon-reload >/dev/null 2>&1 || true
    sleep 0.3
  ) &
  spinner $! "Recargando systemd..."

  echo ""
  hr
  echo -e "  ${G}${BOLD}✓ BADVPN DESINSTALADO COMPLETAMENTE${N}"
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

    local bin_st listen_info
    if is_installed; then
      bin_st="${G}Instalado${N}"
    else
      bin_st="${R}No instalado${N}"
    fi
    listen_info="$(get_listen_info)"

    hr
    echo -e "${W}${BOLD}                BADVPN-UDPGW${N}"
    hr
    echo -e "  ${W}BINARIO:${N}    ${bin_st}  ${D}${BIN}${N}"
    echo -e "  ${W}ESTADO:${N}     $(status_badge)"
    echo -e "  ${W}ESCUCHA:${N}    ${Y}${listen_info}${N}"
    hr

    if ! is_installed; then
      echo ""
      echo -e "  ${G}[${W}1${G}]${N}  ${C}Instalar BadVPN${N}"
      hr
      echo -e "  ${G}[${W}0${G}]${N}  ${W}Volver${N}"
      hr
      echo ""
      echo -ne "  ${W}Opción: ${G}"
      read -r op
      echo -ne "${N}"

      case "${op:-}" in
        1) install_badvpn ;;
        0) break ;;
        *) echo -e "  ${R}Opción inválida${N}"; sleep 1 ;;
      esac
      continue
    fi

    echo ""
    echo -e "  ${G}[${W}1${G}]${N}  ${C}Configurar + Iniciar${N}"
    echo -e "  ${G}[${W}2${G}]${N}  ${C}Iniciar / Parar${N}  $(status_badge)"
    echo -e "  ${G}[${W}3${G}]${N}  ${C}Reiniciar${N}"
    sep
    echo -e "  ${G}[${W}4${G}]${N}  ${C}Ver logs${N}"
    echo -e "  ${G}[${W}5${G}]${N}  ${R}Desinstalar${N}"
    hr
    echo -e "  ${G}[${W}0${G}]${N}  ${W}Volver${N}"
    hr
    echo ""
    echo -ne "  ${W}Opción: ${G}"
    read -r op
    echo -ne "${N}"

    case "${op:-}" in
      1) configure_and_start ;;
      2) start_stop ;;
      3) restart_srv ;;
      4) show_logs ;;
      5) uninstall_all; is_installed || continue ;;
      0) break ;;
      *) echo -e "  ${R}Opción inválida${N}"; sleep 1 ;;
    esac
  done
}

trap 'echo -ne "${N}"; tput cnorm 2>/dev/null; exit 0' SIGINT SIGTERM

main_menu
