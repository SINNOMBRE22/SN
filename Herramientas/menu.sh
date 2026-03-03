#!/bin/bash

# =========================================================
# SinNombre v2.0 - Menú de Herramientas (Ubuntu 22.04+)
# Creador: @SIN_NOMBRE22
# =========================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${ROOT_DIR}/../lib/colores.sh" 2>/dev/null || source "/etc/SN/lib/colores.sh" 2>/dev/null || true

# ===== RUTAS Y VARIABLES ORIGINALES =====
VPS_src="/etc/SN"
VPS_crt="/etc/SN/cert"
L_ROJA="${R}══════════════════════════ / / / ══════════════════════════${N}"

# ===== FUNCIONES INTEGRADAS (ORIGINALES) =====

run_speedtest() {
  header "           SPEEDTEST"
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
  header "           PING TEST"
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
  header "       ACTUALIZAR SISTEMA"
  echo -e "${Y}Actualizando paquetes...${N}"
  apt update && apt upgrade -y
  echo -e "${G}Sistema actualizado.${N}"
  pause
}

clean_cache() {
  header "         LIMPIAR CACHE"
  apt clean && apt autoclean
  rm -rf ~/.cache/thumbnails/*
  echo -e "${G}Cache limpiado.${N}"
  pause
}

change_root_pass() {
  header "    CAMBIAR CONTRASEÑA ROOT"
  passwd root
  pause
}

configure_domain() {
  header "     CONFIGURAR DOMINIO VPS"
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
  header "      VER LOGS DEL SISTEMA"
  journalctl -n 50 --no-pager
  pause
}

restart_services() {
  header "       REINICIAR SERVICIOS"
  systemctl restart sshd 2>/dev/null || true
  systemctl restart cron 2>/dev/null || true
  systemctl restart rsyslog 2>/dev/null || true
  echo -e "${G}Servicios reiniciados.${N}"
  pause
}

auto_start_script() {
  header "     AUTO INICIO DEL SCRIPT"
  script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/menu"
  (crontab -l 2>/dev/null; echo "@reboot $script_path") | crontab -
  echo -e "${G}Auto inicio configurado.${N}"
  pause
}

# ===== MENÚ PRINCIPAL (NUEVO DISEÑO) =====

main_menu() {
  while true; do
    clear_screen
    echo -e "$L_ROJA"
    echo -e "${W}             S I N  N O M B R E  -  M E N U${N}"
    echo -e "$L_ROJA"
    
    # Doble columna con tus opciones originales
    echo -e " ${R}[${Y}01${R}]${N} ${C}Speedtest             ${R}[${Y}08${R}]${N} ${C}Logs del Sistema${N}"
    echo -e " ${R}[${Y}02${R}]${N} ${C}Ping Test             ${R}[${Y}09${R}]${N} ${C}Reiniciar Servicios${N}"
    echo -e " ${R}[${Y}03${R}]${N} ${C}Actualizar Sistema    ${R}[${Y}10${R}]${N} ${C}Auto Inicio Script${N}"
    echo -e " ${R}[${Y}04${R}]${N} ${C}Limpiar Cache         ${R}[${Y}11${R}]${N} ${C}Gestión Cert SSL${N}"
    echo -e " ${R}[${Y}05${R}]${N} ${C}Cambiar Pass Root     ${R}[${Y}12${R}]${N} ${C}Gestión Swap${N}"
    echo -e " ${R}[${Y}06${R}]${N} ${C}Configurar Dominio    ${R}[${Y}13${R}]${N} ${C}Modo Gamer / Accel${N}"
    echo -e " ${R}[${Y}07${R}]${N} ${C}Zona Horaria          ${R}[${Y}14${R}]${N} ${Y}PAYLOAD GENERATOR${N}"
    echo -e "${R}───────────────────────────────────────────────────────────${N}"
    echo -e "             ${R}[${Y}00${R}]${N} ${W}SALIR DEL SCRIPT${N}"
    echo -e "$L_ROJA"
    echo ""
    echo -ne "${W} Selecciona una opción: ${G}"
    read -r option

    case "${option:-}" in
      1|01) run_speedtest ;;
      2|02) ping_test ;;
      3|03) update_system ;;
      4|04) clean_cache ;;
      5|05) change_root_pass ;;
      6|06) configure_domain ;;
      7|07) run_module "zonahora.sh" ;;
      8|08) view_system_logs ;;
      9|09) restart_services ;;
      10) auto_start_script ;;
      11) run_module "ssl.sh" ;;
      12) run_module "swap.sh" ;;
      13) run_module "gamer.sh" ;;
      14) run_module "paygen.sh" ;;
      0|00) exit 0 ;;
      *) echo -e "${R} Opción inválida${N}"; sleep 1 ;;
    esac
  done
}

# Verificación Root
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    clear_screen
    echo -e "$L_ROJA"
    echo -e "${Y}Este menú requiere root.${N}"
    echo -e "$L_ROJA"
    exit 1
fi

main_menu
