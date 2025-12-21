#!/bin/bash
set -euo pipefail

# =========================================================
# SinNombre v1.1 - ADMINISTRADOR DROPBEAR (Actualizado 2024)
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

BANNER_PATH="/etc/dropbear/banner.txt"
DROPBEAR_CONF="/etc/default/dropbear"

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
  local ports
  ports="$(ss -H -lntp 2>/dev/null | awk '$0 ~ /dropbear/ {print $4}' | awk -F: '{print $NF}' | sort -n | uniq | tr '\n' ' ' | sed 's/[[:space:]]\+$//' || true)"
  [[ -n "${ports:-}" ]] && echo "$ports" || echo "No detectado"
}

setup_banner() {
  if [[ ! -f "$BANNER_PATH" ]]; then
    echo "Bienvenido a SinNombre SSH!" > "$BANNER_PATH"
    echo "Servidor personalizado basado en Dropbear." >> "$BANNER_PATH"
    echo "Version: SSH-2.0-dropbear-mod-SinNombre" >> "$BANNER_PATH"
  fi
  chmod 644 "$BANNER_PATH"
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

  setup_banner

  # CONFIGURACION DROPBEAR (keepalive/banner/timeouts)
  if [[ -f "$DROPBEAR_CONF" ]]; then
    cp -a "$DROPBEAR_CONF" "$DROPBEAR_CONF.bak.$(date +%F_%H%M%S)"
  else
    touch "$DROPBEAR_CONF"
    chmod 644 "$DROPBEAR_CONF"
  fi

  # Habilita Dropbear y banner, keepalive cada 60s y timeout de 600s
  sed -i '/^NO_START=/d' "$DROPBEAR_CONF"
  sed -i '/^DROPBEAR_EXTRA_ARGS=/d' "$DROPBEAR_CONF"
  sed -i '/^DROPBEAR_BANNER=/d' "$DROPBEAR_CONF"
  sed -i '/^DROPBEAR_PORT=/d' "$DROPBEAR_CONF"

  echo "NO_START=0" >> "$DROPBEAR_CONF"
  echo "DROPBEAR_PORT=22" >> "$DROPBEAR_CONF"
  echo "DROPBEAR_EXTRA_ARGS=\"-K 60 -I 600 -b $BANNER_PATH\"" >> "$DROPBEAR_CONF"
  echo "DROPBEAR_BANNER=\"$BANNER_PATH\"" >> "$DROPBEAR_CONF"

  systemctl enable dropbear >/dev/null 2>&1 || true
  systemctl restart dropbear >/dev/null 2>&1 || true

  echo -e "${G}Dropbear instalado y configurado.${N}"
  echo -e "${Y}Banner y ajustes de conexión aplicados.${N}"
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

  if [[ ! -f "$DROPBEAR_CONF" ]]; then
    echo -e "${R}No existe $DROPBEAR_CONF. ¿Está instalado Dropbear?${N}"
    pause
    return
  fi

  cp -a "$DROPBEAR_CONF" "$DROPBEAR_CONF.bak.$(date +%F_%H%M%S)"

  sed -i '/^DROPBEAR_PORT=/d' "$DROPBEAR_CONF"
  echo "DROPBEAR_PORT=${newp}" >> "$DROPBEAR_CONF"

  systemctl enable dropbear >/dev/null 2>&1 || true
  systemctl restart dropbear >/dev/null 2>&1 || true

  echo -e "${G}Puerto Dropbear configurado a ${newp} y servicio reiniciado.${N}"
  pause
}

set_banner() {
  clear
  hr
  echo -e "${W}          CONFIGURAR MENSAJE DE BIENVENIDA (BANNER)${N}"
  hr
  echo ""

  echo -e "${Y}Puedes editar el mensaje que verán los usuarios al conectar por SSH.${N}"
  echo -e "El banner actualmente es:\n"
  cat "$BANNER_PATH" 2>/dev/null || echo "(No existe aún)"
  echo ""

  read -r -p "¿Deseas editar el banner (s/n)? " edit
  [[ "${edit,,}" == "s" ]] || { echo "Cancelado."; pause; return; }

  nano "$BANNER_PATH"

  systemctl restart dropbear >/dev/null 2>&1 || true
  echo -e "${G}Banner actualizado.${N}"
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
    echo -e "${R}[${Y}6${R}]${N} ${C}CAMBIAR MENSAJE DE BIENVENIDA (BANNER)${N}"
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
      6) set_banner ;;
      0)  break ;;
      *) echo -e "${B}Opción inválida${N}"; sleep 1 ;;
    esac
  done
}

main_menu
