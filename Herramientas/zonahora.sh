#!/bin/bash

# =========================================================
# Configuración de Zona Horaria - SinNombre
# =========================================================

R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
B='\033[0;34m'
C='\033[0;36m'
W='\033[1;37m'
N='\033[0m'

clear_screen() { clear; }
pause() { read -r -p "Presiona Enter para continuar..."; }

configure_timezone() {
  clear_screen
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
  echo -e "${W}               CONFIGURAR ZONA HORARIA${N}"
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
  echo -e "${Y}Selecciona un continente:${N}"
  echo -e "${R}[${Y}1${R}]${N} ${C}America${N}"
  echo -e "${R}[${Y}2${R}]${N} ${C}Europe${N}"
  echo -e "${R}[${Y}3${R}]${N} ${C}Asia${N}"
  echo -e "${R}[${Y}4${R}]${N} ${C}Africa${N}"
  echo -e "${R}[${Y}5${R}]${N} ${C}Australia${N}"
  echo -e "${R}[${Y}6${R}]${N} ${C}Atlantic${N}"
  echo -e "${R}[${Y}7${R}]${N} ${C}Pacific${N}"
  echo -e "${R}[${Y}0${R}]${N} ${C}Volver${N}"
  echo -ne "${W}Elige: ${G}"
  read -r continent
  case "$continent" in
    1) tz_prefix="America" ;;
    2) tz_prefix="Europe" ;;
    3) tz_prefix="Asia" ;;
    4) tz_prefix="Africa" ;;
    5) tz_prefix="Australia" ;;
    6) tz_prefix="Atlantic" ;;
    7) tz_prefix="Pacific" ;;
    0) return ;;
    *) echo -e "${B}Opción inválida${N}"; sleep 2; configure_timezone; return ;;
  esac
  echo -e "${Y}Zonas horarias para $tz_prefix:${N}"
  timezones=($(timedatectl list-timezones | grep "^$tz_prefix/"))
  for i in "${!timezones[@]}"; do
    echo -e "${R}[${Y}$((i+1))${R}]${N} ${Y}${timezones[$i]}${N}"
  done
  echo -ne "${W}Elige una zona horaria: ${G}"
  read -r tz_choice
  if [[ "$tz_choice" =~ ^[0-9]+$ && "$tz_choice" -ge 1 && "$tz_choice" -le "${#timezones[@]}" ]]; then
    selected_tz="${timezones[$((tz_choice-1))]}"
    timedatectl set-timezone "$selected_tz"
    echo -e "${G}Zona horaria configurada a: $selected_tz${N}"
  else
    echo -e "${B}Selección inválida${N}"
  fi
  pause
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    clear_screen
    echo -e "${R}Este menú requiere root.${N}"
    exit 1
  fi
}

require_root
configure_timezone
