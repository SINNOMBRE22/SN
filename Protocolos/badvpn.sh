
#!/bin/bash
set -euo pipefail

# =========================================================
# SinNombre - BADVPN-UDPGW (Compat Rufu / Multi-Script)
# Archivo: SN/Protocolos/badvpn.sh
#
# Basado en: NetVPS/Multi-Script R9/Utils/badvpn/budp.sh
# - Instala badvpn-udpgw en: /usr/bin/badvpn-udpgw
# - Crea servicio systemd: /etc/systemd/system/badvpn.service
# - Servicio: badvpn
# =========================================================

R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
B='\033[0;34m'
C='\033[0;36m'
W='\033[1;37m'
N='\033[0m'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

pause(){ echo ""; read -r -p "Presiona Enter para continuar..."; }
hr(){ echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"; }
sep(){ echo -e "${R}------------------------------------------------------------${N}"; }
require_root(){ [[ "${EUID:-$(id -u)}" -eq 0 ]] || { echo -e "${R}Ejecuta como root.${N}"; exit 1; }; }

BIN="/usr/bin/badvpn-udpgw"
SVC="/etc/systemd/system/badvpn.service"
LOCK="/root/udp-rufu"

is_on(){
  systemctl is-active --quiet badvpn 2>/dev/null && return 0
  pgrep -x badvpn-udpgw >/dev/null 2>&1 && return 0
  return 1
}
status_badge(){ is_on && echo -e "${G}[ON ]${N}" || echo -e "${R}[OFF]${N}"; }

install_deps(){
  apt-get update -y >/dev/null 2>&1 || true
  apt-get install -y wget unzip cmake make gcc g++ build-essential lsof >/dev/null 2>&1
}

install_badvpn(){
  clear; hr
  echo -e "${W}         INSTALAR BADVPN-UDPGW${N}"
  hr

  install_deps

  # estilo Rufu: primera vez limpia rastros viejos
  if [[ ! -e "$LOCK" ]]; then
    rm -f /usr/bin/badvpn-udpgw /bin/badvpn-udpgw >/dev/null 2>&1 || true
    touch "$LOCK" >/dev/null 2>&1 || true
  fi

  if [[ -x "$BIN" ]]; then
    echo -e "${Y}Ya está instalado:${N} ${C}${BIN}${N}"
    pause
    return
  fi

  cd /root
  rm -rf /root/badvpn-master /root/badvpn-master.zip >/dev/null 2>&1 || true

  sep
  echo -e "${W}Descargando badvpn-master.zip...${N}"
  sep

  # Puedes cambiar la URL si quieres usar TU repo o una fija
  wget -qO /root/badvpn-master.zip "https://github.com/NetVPS/Multi-Script/raw/main/R9/Utils/badvpn/badvpn-master.zip" || {
    echo -e "${R}Fallo descarga del zip.${N}"
    pause
    return
  }

  sep
  echo -e "${W}Descomprimiendo...${N}"
  sep
  unzip -oq /root/badvpn-master.zip -d /root || {
    echo -e "${R}Fallo al descomprimir.${N}"
    pause
    return
  }

  cd /root/badvpn-master
  mkdir -p build
  cd build

  sep
  echo -e "${W}Compilando e instalando (udpgw)...${N}"
  sep
  cmake .. -DCMAKE_INSTALL_PREFIX="/" -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1 >/dev/null 2>&1 || {
    echo -e "${R}Fallo cmake.${N}"
    pause
    return
  }
  make install >/dev/null 2>&1 || {
    echo -e "${R}Fallo make install.${N}"
    pause
    return
  }

  rm -rf /root/badvpn-master /root/badvpn-master.zip >/dev/null 2>&1 || true

  clear; hr
  echo -e "${G}BADVPN INSTALADO${N}"
  hr
  echo -e "${W}Binario:${N} ${C}${BIN}${N}"
  hr
  pause
}

write_service(){
  local ip="$1" port="$2" max_clients="$3" max_conn="$4"

  cat >"$SVC" <<EOF
[Unit]
Description=BadVPN UDPGW Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root
ExecStart=${BIN} --listen-addr ${ip}:${port} --max-clients ${max_clients} --max-connections-for-client ${max_conn}
Restart=always
RestartSec=3s

[Install]
WantedBy=multi-user.target
EOF
}

configure_and_start(){
  clear; hr
  echo -e "${W}       CONFIGURAR / INICIAR BADVPN${N}"
  hr

  [[ -x "$BIN" ]] || { echo -e "${R}No está instalado. Usa opción 1 primero.${N}"; pause; return; }

  local ip port max_clients max_conn
  read -r -p "IP listen [127.0.0.1]: " ip
  ip="${ip:-127.0.0.1}"

  read -r -p "Puerto [7300]: " port
  port="${port:-7300}"
  [[ "$port" =~ ^[0-9]+$ ]] || port="7300"

  read -r -p "Max clients [1000]: " max_clients
  max_clients="${max_clients:-1000}"
  [[ "$max_clients" =~ ^[0-9]+$ ]] || max_clients="1000"

  read -r -p "Max conexiones por cliente [10]: " max_conn
  max_conn="${max_conn:-10}"
  [[ "$max_conn" =~ ^[0-9]+$ ]] || max_conn="10"

  write_service "$ip" "$port" "$max_clients" "$max_conn"

  systemctl daemon-reload >/dev/null 2>&1 || true
  systemctl enable badvpn >/dev/null 2>&1 || true
  systemctl restart badvpn >/dev/null 2>&1 || true
  sleep 1

  clear; hr
  echo -e "${W}Estado:${N} $(status_badge)"
  echo -e "${W}Servicio:${N} ${Y}badvpn${N}"
  echo -e "${W}Escuchando:${N} ${Y}${ip}:${port}${N}"
  hr
  pause
}

start_stop(){
  clear; hr
  if is_on; then
    echo -e "${Y}Deteniendo BADVPN...${N}"
    systemctl stop badvpn >/dev/null 2>&1 || true
  else
    echo -e "${G}Iniciando BADVPN...${N}"
    systemctl start badvpn >/dev/null 2>&1 || true
  fi
  hr
  echo -e "${W}Estado:${N} $(status_badge)"
  hr
  pause
}

restart_srv(){
  clear; hr
  systemctl restart badvpn >/dev/null 2>&1 || true
  echo -e "${G}Reiniciado.${N}"
  hr
  pause
}

logs(){
  clear; hr
  echo -e "${W}LOGS BADVPN (últimas 200 líneas)${N}"
  hr
  journalctl -u badvpn -n 200 --no-pager 2>/dev/null || true
  hr
  pause
}

uninstall_all(){
  clear; hr
  echo -e "${R}       DESINSTALAR BADVPN${N}"
  hr
  read -r -p "¿Confirmas? (s/n): " yn
  [[ "${yn,,}" == "s" ]] || return

  systemctl stop badvpn >/dev/null 2>&1 || true
  systemctl disable badvpn >/dev/null 2>&1 || true
  rm -f "$SVC" >/dev/null 2>&1 || true
  systemctl daemon-reload >/dev/null 2>&1 || true

  rm -f "$BIN" /bin/badvpn-udpgw >/dev/null 2>&1 || true

  echo -e "${G}Desinstalado.${N}"
  pause
}

main_menu(){
  require_root
  while true; do
    clear
    hr
    echo -e "${W}               BADVPN-UDPGW${N}"
    hr
    echo -e "${R}[${N} ${W}BINARIO:${N} $([[ -x "$BIN" ]] && echo -e "${G}OK${N}" || echo -e "${R}NO${N}")  ${C}${BIN}${N}"
    echo -e "${R}[${N} ${W}SERVICIO:${N} $(status_badge)  ${Y}badvpn${N}"
    hr

    echo -e "${R}[${Y}1${R}]${N} ${C}INSTALAR / COMPILAR${N}"
    echo -e "${R}[${Y}2${R}]${N} ${C}CONFIGURAR + INICIAR${N}"
    sep
    echo -e "${R}[${Y}3${R}]${N} ${C}INICIAR / PARAR${N} $(status_badge)"
    echo -e "${R}[${Y}4${R}]${N} ${C}REINICIAR${N}"
    echo -e "${R}[${Y}5${R}]${N} ${C}VER LOGS${N}"
    sep
    echo -e "${R}[${Y}6${R}]${N} ${C}DESINSTALAR TODO${N}"

    hr
    echo -e "${R}[${Y}0${R}]${N} ${W}VOLVER${N}"
    hr
    echo ""
    echo -ne "${W}Ingresa una opcion: ${G}"
    read -r op

    case "${op:-}" in
      1) install_badvpn ;;
      2) configure_and_start ;;
      3) start_stop ;;
      4) restart_srv ;;
      5) logs ;;
      6) uninstall_all ;;
      0)  break ;;
      *) echo -e "${B}Opción inválida${N}"; sleep 1 ;;
    esac
  done
}

main_menu
