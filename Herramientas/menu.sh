#!/bin/bash

# =========================================================
# SinNombre v2.0 - Menú de Herramientas (Ubuntu 22.04+)
# Creador: @SIN_NOMBRE22
# =========================================================

R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
B='\033[0;34m'
C='\033[0;36m'
W='\033[1;37m'
N='\033[0m'

# ===== RUTAS BASE SN =====
VPS_src="/etc/SN"
VPS_crt="/etc/SN/cert"

clear_screen() { clear; }

pause() {
  echo ""
  read -r -p "Presiona Enter para continuar..."
}

run_module() {
  local rel="$1"
  local path="${ROOT_DIR}/${rel}"
  if [[ -f "$path" ]]; then
    bash "$path"
    clear_screen
  else
    echo ""
    echo -e "${Y}Módulo no disponible:${N} ${C}${rel}${N}"
    echo -e "${Y}Estado:${N} En desarrollo..."
    pause
  fi
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

run_speedtest() {
  clear_screen
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
  echo -e "${W}                     SPEEDTEST${N}"
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
  if command -v speedtest-cli &>/dev/null; then
    speedtest-cli --simple
  else
    echo -e "${Y}Instalando speedtest-cli...${N}"
    apt update && apt install -y speedtest-cli
    speedtest-cli --simple
  fi
  pause
}

ping_test() {
  clear_screen
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
  echo -e "${W}                     PING TEST${N}"
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
  echo -ne "${W}Ingresa la IP o dominio a pinguear: ${G}"
  read -r target
  if [[ -n "${target:-}" ]]; then
    ping -c 4 "$target"
  else
    echo -e "${Y}No se ingresó un objetivo.${N}"
  fi
  pause
}

update_system() {
  clear_screen
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
  echo -e "${W}                  ACTUALIZAR SISTEMA${N}"
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
  echo -e "${Y}Actualizando lista de paquetes...${N}"
  apt update
  echo -e "${Y}Actualizando paquetes...${N}"
  apt upgrade -y
  echo -e "${G}Sistema actualizado.${N}"
  pause
}

clean_cache() {
  clear_screen
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
  echo -e "${W}                   LIMPIAR CACHE${N}"
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
  echo -e "${Y}Limpiando cache de apt...${N}"
  apt clean
  apt autoclean
  echo -e "${Y}Limpiando cache de thumbnails...${N}"
  rm -rf ~/.cache/thumbnails/*
  echo -e "${G}Cache limpiado.${N}"
  pause
}

change_root_pass() {
  clear_screen
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
  echo -e "${W}              CAMBIAR CONTRASEÑA ROOT${N}"
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
  echo -e "${Y}Cambiando contraseña de root...${N}"
  passwd root
  echo -e "${G}Contraseña cambiada.${N}"
  pause
}

configure_domain() {
  clear_screen
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
  echo -e "${W}               CONFIGURAR DOMINIO VPS${N}"
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
  mkdir -p "$VPS_src"
  echo -ne "${W}Ingresa el dominio de la VPS: ${G}"
  read -r domain
  if [[ -n "${domain:-}" ]]; then
    echo "$domain" > "${VPS_src}/dominio.txt"
    echo -e "${G}Dominio configurado: $domain${N}"
  else
    echo -e "${Y}No se ingresó dominio.${N}"
  fi
  pause
}

view_system_logs() {
  clear_screen
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
  echo -e "${W}                  VER LOGS DEL SISTEMA${N}"
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
  echo -e "${Y}Mostrando logs recientes (últimas 50 líneas)...${N}"
  journalctl -n 50 --no-pager
  pause
}

restart_services() {
  clear_screen
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
  echo -e "${W}               REINICIAR SERVICIOS${N}"
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
  echo -e "${Y}Reiniciando servicios comunes...${N}"
  systemctl restart sshd 2>/dev/null || true
  systemctl restart cron 2>/dev/null || true
  systemctl restart rsyslog 2>/dev/null || true
  echo -e "${G}Servicios reiniciados.${N}"
  pause
}

auto_start_script() {
  clear_screen
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
  echo -e "${W}            CONFIGURAR AUTO INICIO DEL SCRIPT${N}"
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
  echo -e "${Y}Agregando script al crontab para auto inicio...${N}"
  script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/menu"
  (crontab -l 2>/dev/null; echo "@reboot $script_path") | crontab -
  echo -e "${G}Auto inicio configurado.${N}"
  pause
}

invalid_option() {
  clear_screen
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
  echo -e "${B}                   OPCIÓN INVÁLIDA${N}"
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
  sleep 2
}

main_menu() {
  while true; do
    clear_screen
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${W}                 MENÚ DE HERRAMIENTAS${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${R}[${Y}1${R}]${N}  ${C}Speedtest${N}"
    echo -e "${R}───────────────────────────────────────────────────────────${N}"
    echo -e "${R}[${Y}2${R}]${N}  ${C}Ping Test${N}"
    echo -e "${R}───────────────────────────────────────────────────────────${N}"
    echo -e "${R}[${Y}3${R}]${N}  ${C}Actualizar Sistema${N}"
    echo -e "${R}───────────────────────────────────────────────────────────${N}"
    echo -e "${R}[${Y}4${R}]${N}  ${C}Limpiar Cache${N}"
    echo -e "${R}───────────────────────────────────────────────────────────${N}"
    echo -e "${R}[${Y}5${R}]${N}  ${C}Cambiar Pass Root${N}"
    echo -e "${R}───────────────────────────────────────────────────────────${N}"
    echo -e "${R}[${Y}6${R}]${N}  ${C}Configurar Dominio${N}"
    echo -e "${R}───────────────────────────────────────────────────────────${N}"
    echo -e "${R}[${Y}7${R}]${N}  ${C}Configurar Zona Horaria${N}"
    echo -e "${R}───────────────────────────────────────────────────────────${N}"
    echo -e "${R}[${Y}8${R}]${N}  ${C}Ver Logs del Sistema${N}"
    echo -e "${R}───────────────────────────────────────────────────────────${N}"
    echo -e "${R}[${Y}9${R}]${N}  ${C}Reiniciar Servicios${N}"
    echo -e "${R}───────────────────────────────────────────────────────────${N}"
    echo -e "${R}[${Y}10${R}]${N} ${C}Auto Inicio del Script${N}"
    echo -e "${R}───────────────────────────────────────────────────────────${N}"
    echo -e "${R}[${Y}11${R}]${N} ${C}Gestión de Certificados SSL${N}"
    echo -e "${R}───────────────────────────────────────────────────────────${N}"
    echo -e "${R}[${Y}12${R}]${N} ${C}Gestión de Memoria Swap${N}"
    echo -e "${R}───────────────────────────────────────────────────────────${N}"
    echo -e "${R}[${Y}13${R}]${N} ${C}Modo Gamer / Acelerador${N}"
    echo -e "${R}───────────────────────────────────────────────────────────${N}"
    echo -e "${R}[${Y}0${R}]${N}  ${C}VOLVER${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo ""
    echo -ne "${W}Selecciona una opción: ${G}"
    read -r option

    case "${option:-}" in
      1) run_speedtest ;;
      2) ping_test ;;
      3) update_system ;;
      4) clean_cache ;;
      5) change_root_pass ;;
      6) configure_domain ;;
      7) run_module "zonahora.sh" ;;
      8) view_system_logs ;;
      9) restart_services ;;
      10) auto_start_script ;;
      11) run_module "ssl.sh" ;;
      12) run_module "swap.sh" ;;
      13) run_module "gamer.sh" ;;
      0) return 0 ;;
      *)
        invalid_option
        ;;
    esac
  done
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    clear_screen
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${Y}Este menú requiere root.${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    exit 1
  fi
}

trap return SIGINT SIGTERM

require_root
main_menu
