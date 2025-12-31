#!/bin/bash

# =========================================================
# Gestión de Memoria Swap - SinNombre
# =========================================================

R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
B='\033[0;34m'
C='\033[0;36m'
W='\033[1;37m'
N='\033[0m'

swap="/swapfile"
fstab="/etc/fstab"
sysctl="/etc/sysctl.conf"

clear_screen() { clear; }
pause() { read -r -p "Presiona Enter para continuar..."; }

funcion_crear() {
  if [[ -e "/swapfile" ]]; then
    echo -e "${Y}Deteniendo memoria swap${N}"
    swapoff -a
    sed -i '/swap/d' /etc/fstab
    sed -i '/vm.swappiness/d' /etc/sysctl.conf
    sysctl -p
    rm -rf /swapfile
    echo -e "${G}Swapfile detenido${N}"
    pause
    return
  fi
  memoria=$(dmidecode --type memory | grep ' MB' | awk '{print $2}')
  if [[ "$memoria" -gt "2048" ]]; then
    echo -e "${Y}No es necesario swap (más de 2GB RAM)${N}"
    pause
    return
  fi
  echo -e "${Y}Creando swapfile de 2GB${N}"
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  echo -e "${G}Swapfile creado${N}"
  pause
}

funcion_activar() {
  echo -e "${W}Activar Swapfile${N}"
  echo -e "${R}[${Y}1${R}]${N}  ${C}Permanente${N}"
  echo -e "${R}[${Y}2${R}]${N}  ${C}Hasta el próximo reinicio${N}"
  echo -e "${R}[${Y}0${R}]${N}  ${C}Volver${N}"
  echo -ne "${W}Selecciona: ${G}"
  read -r opcion
  case $opcion in
    1) sed -i '/swap/d' "$fstab"
       echo "$swap none swap sw 0 0" >> "$fstab"
       swapon "$swap"
       echo -e "${G}Swapfile activado permanentemente${N}" ;;
    2) swapon "$swap"
       echo -e "${G}Swapfile activado hasta reinicio${N}" ;;
    0) return ;;
    *) echo -e "${B}Opción inválida${N}" ;;
  esac
  pause
}

funcion_prio() {
  echo -e "${W}Prioridad Swap${N}"
  echo -e "${R}[${Y}1${R}]${N}  ${C}10${N}"
  echo -e "${R}[${Y}2${R}]${N}  ${C}20 (recomendado)${N}"
  echo -e "${R}[${Y}3${R}]${N}  ${C}30${N}"
  echo -e "${R}[${Y}4${R}]${N}  ${C}40${N}"
  echo -e "${R}[${Y}5${R}]${N}  ${C}50${N}"
  echo -e "${R}[${Y}6${R}]${N}  ${C}60${N}"
  echo -e "${R}[${Y}7${R}]${N}  ${C}70${N}"
  echo -e "${R}[${Y}8${R}]${N}  ${C}80${N}"
  echo -e "${R}[${Y}9${R}]${N}  ${C}90${N}"
  echo -e "${R}[${Y}10${R}]${N} ${C}100${N}"
  echo -e "${R}[${Y}0${R}]${N}  ${C}Volver${N}"
  echo -ne "${W}Selecciona: ${G}"
  read -r opcion
  if [[ $opcion -ge 1 && $opcion -le 10 ]]; then
    prio=$((opcion * 10))
    sed -i '/vm.swappiness=/d' "$sysctl"
    echo "vm.swappiness=$prio" >> "$sysctl"
    sysctl -p &>/dev/null
    echo -e "${G}Prioridad swap en $prio${N}"
  elif [[ $opcion == 0 ]]; then
    return
  else
    echo -e "${B}Opción inválida${N}"
  fi
  pause
}

main_menu() {
  while true; do
    clear_screen
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${W}              GESTIÓN DE MEMORIA SWAP${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${R}[${Y}1${R}]${N}  ${C}Crear/Desactivar Swapfile${N}"
    echo -e "${R}[${Y}2${R}]${N}  ${C}Activar Swap${N}"
    echo -e "${R}[${Y}3${R}]${N}  ${C}Prioridad Swap${N}"
    echo -e "${R}[${Y}0${R}]${N}  ${C}VOLVER${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo ""
    echo -ne "${W}Selecciona una opción: ${G}"
    read -r option
    case "${option:-}" in
      1) funcion_crear ;;
      2) funcion_activar ;;
      3) funcion_prio ;;
      0) return ;;
      *)
        echo -e "${B}Opción inválida${N}"
        sleep 2
        ;;
    esac
  done
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    clear_screen
    echo -e "${R}Este menú requiere root.${N}"
    exit 1
  fi
}

require_root
main_menu
