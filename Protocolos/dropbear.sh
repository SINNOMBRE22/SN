#!/bin/bash
set -euo pipefail

# =========================================================
# SinNombre v1.0 - ADMINISTRADOR DROPBEAR (Diseño original)
# Archivo: SN/Protocolos/dropbear.sh
# =========================================================

R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
B='\033[0;34m'
M='\033[0;35m'
C='\033[0;36m'
W='\033[1;37m'
N='\033[0m'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

pause() { echo ""; read -r -p "Presiona Enter para continuar..."; }

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo -e "${R}Ejecuta como root.${N}"
    exit 1
  fi
}

hr() { echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"; }

is_installed() { command -v dropbear >/dev/null 2>&1; }

is_on() {
  systemctl is-active --quiet dropbear 2>/dev/null || pgrep -x dropbear >/dev/null 2>&1
}

badge() {
  if is_on; then
    echo -e "${G}[ON]${N}"
  else
    echo -e "${R}[OFF]${N}"
  fi
}

get_ports() {
  # Puertos escuchando por dropbear
  local ports
  ports="$(ss -H -lntp 2>/dev/null | awk '$0 ~ /dropbear/ {print $4}' | awk -F: '{print $NF}' | sort -n | uniq | tr '\n' ' ' | sed 's/[[:space:]]\+$//' || true)"
  [[ -n "${ports:-}" ]] && echo "$ports" || echo "No detectado"
}

install_dropbear() {
  clear
  hr
  echo -e "${W}                 INSTALAR DROPBEAR${N}"
  hr

  if is_installed; then
    echo -e "${Y}Dropbear ya está instalado.${N}"
    pause
    return
  fi

  apt-get update -y >/dev/null 2>&1 || true
  apt-get install -y dropbear >/dev/null 2>&1 || true

  echo -e "${G}Dropbear instalado.${N}"
  pause
}

set_port() {
  clear
  hr
  echo -e "${W}              CONFIGURAR PUERTO DROPBEAR${N}"
  hr
  echo -e "${Y}Nota:${N} En Ubuntu/Debian se configura en /etc/default/dropbear"
  echo ""

  read -r -p "Nuevo puerto Dropbear: " newp
  [[ "${newp:-}" =~ ^[0-9]+$ ]] || { echo -e "${R}Puerto inválido.${N}"; pause; return; }
  (( newp >= 1 && newp <= 65535 )) || { echo -e "${R}Puerto fuera de rango.${N}"; pause; return; }

  if [[ ! -f /etc/default/dropbear ]]; then
    echo -e "${R}No existe /etc/default/dropbear. ¿Está instalado Dropbear?${N}"
    pause
    return
  fi

  cp -a /etc/default/dropbear "/etc/default/dropbear.bak.$(date +%F_%H%M%S)"

  # Asegura habilitado
  if grep -qE '^NO_START=' /etc/default/dropbear; then
    sed -i 's/^NO_START=.*/NO_START=0/' /etc/default/dropbear
  else
    echo "NO_START=0" >> /etc/default/dropbear
  fi

  # Ajusta puerto
  if grep -qE '^DROPBEAR_PORT=' /etc/default/dropbear; then
    sed -i "s/^DROPBEAR_PORT=.*/DROPBEAR_PORT=${newp}/" /etc/default/dropbear
  else
    echo "DROPBEAR_PORT=${newp}" >> /etc/default/dropbear
  fi

  systemctl enable dropbear >/dev/null 2>&1 || true
  systemctl restart dropbear >/dev/null 2>&1 || true

  echo -e "${G}Puerto Dropbear configurado a ${newp} y servicio reiniciado.${N}"
  pause
}

toggle_service() {
  if ! is_installed; then
    echo -e "${R}Dropbear no está instalado.${N}"
    pause
    return
  fi

  if is_on; then
    systemctl stop dropbear >/dev/null 2>&1 || true
    systemctl disable dropbear >/dev/null 2>&1 || true
  else
    systemctl enable dropbear >/dev/null 2>&1 || true
    systemctl start dropbear >/dev/null 2>&1 || true
  fi
}

restart_service() {
  if ! is_installed; then
    echo -e "${R}Dropbear no está instalado.${N}"
    pause
    return
  fi
  systemctl restart dropbear >/dev/null 2>&1 || true
}

uninstall_dropbear() {
  clear
  hr
  echo -e "${R}               DESINSTALAR DROPBEAR${N}"
  hr
  echo -e "${Y}Advertencia:${N} esto eliminará Dropbear del sistema."
  echo ""
  read -r -p "¿Confirmas desinstalar dropbear? (s/n): " yn
  [[ "${yn,,}" == "s" ]] || { echo "Cancelado."; pause; return; }

  systemctl stop dropbear >/dev/null 2>&1 || true
  apt-get remove -y dropbear >/dev/null 2>&1 || true
  apt-get autoremove -y >/dev/null 2>&1 || true

  echo -e "${G}Dropbear desinstalado.${N}"
  pause
}

main_menu() {
  require_root

  while true; do
    clear
    local st ports
    st="$(badge)"
    ports="$(get_ports)"

    hr
    echo -e "${W}               ADMINISTRADOR DROPBEAR${N}"
    hr
    echo -e "${R}[${N} ${W}PUERTOS:${N} ${Y}${ports}${N}"
    echo -e "${R}[${N} ${W}ESTADO:${N}  ${st}"
    hr

    echo -e "${R}[${Y}1${R}]${N} ${C}INSTALAR DROPBEAR${N}"
    echo -e "${R}[${Y}2${R}]${N} ${C}CONFIGURAR PUERTO DROPBEAR${N}"
    echo -e "${R}[${Y}3${R}]${N} ${C}INICIAR/DETENER DROPBEAR${N} ${st}"
    echo -e "${R}[${Y}4${R}]${N} ${C}REINICIAR DROPBEAR${N}"
    echo -e "${R}[${Y}5${R}]${N} ${C}DESINSTALAR DROPBEAR${N}"
    echo -e "${R}[${Y}0${R}]${N} ${W}VOLVER${N}"

    hr
    echo ""
    echo -ne "${W}Ingresa una Opcion: ${G}"
    read -r op

    case "${op:-}" in
      1) install_dropbear ;;
      2) set_port ;;
      3) toggle_service ;;
      4) restart_service; echo -e "${G}Dropbear reiniciado.${N}"; pause ;;
      5) uninstall_dropbear ;;
      0)  break ;;
      *) echo -e "${B}Opción inválida${N}"; sleep 1 ;;
    esac
  done
}

main_menu
