#!/bin/bash
set -euo pipefail

# =========================================================
# SinNombre v1.0 - BADVPN-UDPGW (Estilo SN / ADMRufu-like)
# Archivo: SN/Protocolos/badvpn.sh
#
# Crea:
# - /usr/local/bin/badvpn-udpgw
# - /etc/systemd/system/badvpn-udpgw.service
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
have(){ command -v "$1" >/dev/null 2>&1; }

BIN="/usr/local/bin/badvpn-udpgw"
SVC="/etc/systemd/system/badvpn-udpgw.service"

is_on(){
  systemctl is-active --quiet badvpn-udpgw 2>/dev/null && return 0
  pgrep -x badvpn-udpgw >/dev/null 2>&1 && return 0
  return 1
}

status_badge(){
  is_on && echo -e "${G}[ON ]${N}" || echo -e "${R}[OFF]${N}"
}

pm_install_deps(){
  if ! have apt-get; then
    echo -e "${R}Este módulo por ahora requiere apt-get (Ubuntu/Debian).${N}"
    return 1
  fi
  apt-get update -y >/dev/null 2>&1 || true
  apt-get install -y git cmake make gcc g++ build-essential >/dev/null 2>&1
  return 0
}

install_build(){
  clear
  hr
  echo -e "${W}          INSTALADOR BADVPN-UDPGW${N}"
  hr

  pm_install_deps || { pause; return; }

  if [[ -x "$BIN" ]]; then
    echo -e "${Y}Ya existe:${N} ${C}${BIN}${N}"
    read -r -p "¿Recompilar/instalar de nuevo? (s/n): " yn
    [[ "${yn,,}" == "s" ]] || { pause; return; }
  fi

  local tmp="/tmp/badvpn-src"
  rm -rf "$tmp" >/dev/null 2>&1 || true

  sep
  echo -e "${W}Clonando repositorio...${N}"
  sep
  git clone --depth 1 https://github.com/ambrop72/badvpn.git "$tmp" >/dev/null 2>&1 || {
    echo -e "${R}Error clonando badvpn.${N}"
    pause
    return
  }

  sep
  echo -e "${W}Compilando (udpgw)...${N}"
  sep
  mkdir -p "$tmp/build"
  cd "$tmp/build"
  cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1 >/dev/null 2>&1 || {
    echo -e "${R}Error en cmake.${N}"
    pause
    return
  }
  make -j"$(nproc)" >/dev/null 2>&1 || {
    echo -e "${R}Error compilando.${N}"
    pause
    return
  }

  install -m 0755 udpgw/badvpn-udpgw "$BIN" || {
    echo -e "${R}No se pudo instalar el binario.${N}"
    pause
    return
  }

  rm -rf "$tmp" >/dev/null 2>&1 || true

  clear
  hr
  echo -e "${G}BADVPN-UDPGW INSTALADO${N}"
  hr
  echo -e "${W}Binario:${N} ${C}${BIN}${N}"
  hr
  pause
}

create_or_update_service(){
  clear
  hr
  echo -e "${W}          CONFIGURAR SERVICIO BADVPN${N}"
  hr

  [[ -x "$BIN" ]] || { echo -e "${R}No está instalado el binario. Usa opción 1.${N}"; pause; return; }

  local port max_clients buf mtu
  read -r -p "Ingrese puerto UDPGW [7300]: " port
  port="${port:-7300}"
  [[ "$port" =~ ^[0-9]+$ ]] || port="7300"

  read -r -p "Max clients [1024]: " max_clients
  max_clients="${max_clients:-1024}"
  [[ "$max_clients" =~ ^[0-9]+$ ]] || max_clients="1024"

  read -r -p "Buffer (bytes) [65536]: " buf
  buf="${buf:-65536}"
  [[ "$buf" =~ ^[0-9]+$ ]] || buf="65536"

  read -r -p "UDP MTU [1500]: " mtu
  mtu="${mtu:-1500}"
  [[ "$mtu" =~ ^[0-9]+$ ]] || mtu="1500"

  cat >"$SVC" <<EOF
[Unit]
Description=BadVPN UDPGW
After=network.target

[Service]
Type=simple
User=root
ExecStart=${BIN} --listen-addr 0.0.0.0:${port} --max-clients ${max_clients} --udp-mtu ${mtu} --client-socket-sndbuf ${buf} --client-socket-rcvbuf ${buf}
Restart=always
RestartSec=2s

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload >/dev/null 2>&1 || true
  systemctl enable --now badvpn-udpgw >/dev/null 2>&1 || true

  clear
  hr
  echo -e "${G}SERVICIO CONFIGURADO${N}"
  hr
  echo -e "${W}Puerto:${N} ${Y}${port}${N}"
  echo -e "${W}Estado:${N} $(status_badge)"
  hr
  pause
}

start_stop(){
  clear
  hr
  if is_on; then
    systemctl stop badvpn-udpgw >/dev/null 2>&1 || true
    echo -e "${Y}Servicio detenido.${N}"
  else
    systemctl start badvpn-udpgw >/dev/null 2>&1 || true
    echo -e "${G}Servicio iniciado.${N}"
  fi
  hr
  pause
}

restart_svc(){
  clear
  hr
  systemctl restart badvpn-udpgw >/dev/null 2>&1 || true
  echo -e "${G}Servicio reiniciado.${N}"
  hr
  pause
}

show_logs(){
  clear
  hr
  echo -e "${W}LOGS BADVPN-UDPGW (últimas 200 líneas)${N}"
  hr
  journalctl -u badvpn-udpgw -n 200 --no-pager 2>/dev/null || true
  hr
  pause
}

uninstall_all(){
  clear
  hr
  echo -e "${R}          DESINSTALAR BADVPN-UDPGW${N}"
  hr
  read -r -p "¿Confirmas desinstalar todo? (s/n): " yn
  [[ "${yn,,}" == "s" ]] || return

  systemctl stop badvpn-udpgw >/dev/null 2>&1 || true
  systemctl disable badvpn-udpgw >/dev/null 2>&1 || true
  rm -f "$SVC" >/dev/null 2>&1 || true
  systemctl daemon-reload >/dev/null 2>&1 || true
  rm -f "$BIN" >/dev/null 2>&1 || true

  clear
  hr
  echo -e "${G}BADVPN-UDPGW DESINSTALADO${N}"
  hr
  pause
}

main_menu(){
  require_root

  while true; do
    clear
    local st
    st="$(status_badge)"

    hr
    echo -e "${W}               BADVPN-UDPGW${N}"
    hr
    echo -e "${R}[${N} ${W}BINARIO:${N} $([[ -x "$BIN" ]] && echo -e "${G}OK${N}" || echo -e "${R}NO${N}")  ${C}${BIN}${N}"
    echo -e "${R}[${N} ${W}SERVICIO:${N} ${st}"
    hr

    echo -e "${R}[${Y}1${R}]${N} ${C}INSTALAR / COMPILAR${N}"
    echo -e "${R}[${Y}2${R}]${N} ${C}CONFIGURAR SERVICIO (PUERTO) + INICIAR${N}"
    sep
    echo -e "${R}[${Y}3${R}]${N} ${C}INICIAR / PARAR${N} ${st}"
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
      1) install_build ;;
      2) create_or_update_service ;;
      3) start_stop ;;
      4) restart_svc ;;
      5) show_logs ;;
      6) uninstall_all ;;
      0) bash "${ROOT_DIR}/Protocolos/menu.sh" ;;
      *) echo -e "${B}Opción inválida${N}"; sleep 1 ;;
    esac
  done
}

main_menu
