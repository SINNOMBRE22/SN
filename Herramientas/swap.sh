#!/bin/bash
set -euo pipefail

# =========================================================
# SinNombre v1.0 - GESTIÓN DE MEMORIA SWAP
# Adaptación visual: @SIN_NOMBRE22
# =========================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── Cargar colores desde lib ────────────────────────────
LIB_COLORES="$ROOT_DIR/lib/colores.sh"
if [[ -f "$LIB_COLORES" ]]; then
  source "$LIB_COLORES"
else
  # Fallback: colores básicos
  R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'
  W='\033[1;37m'; N='\033[0m'; BOLD='\033[1m'
  hr()  { echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"; }
  sep() { echo -e "${R}──────────────────────────────────────────────────────────${N}"; }
  pause() { echo ""; read -r -p "Presiona Enter para continuar..."; }
  clear_screen() { clear; }
fi

# ── Configuración ────────────────────────────────────────
swap="/swapfile"
fstab="/etc/fstab"
sysctl_conf="/etc/sysctl.conf"

# ── Funciones Lógicas ────────────────────────────────────

funcion_crear() {
  if [[ -e "$swap" ]]; then
    echo -e "  ${Y}•${N} ${W}Deteniendo y eliminando memoria SWAP existente...${N}"
    swapoff "$swap" 2>/dev/null || true
    sed -i '/swapfile/d' "$fstab"
    sed -i '/vm.swappiness/d' "$sysctl_conf"
    sysctl -p "$sysctl_conf" &>/dev/null || true
    rm -f "$swap"
    echo -e "  ${G}✓ Swapfile eliminado correctamente.${N}"
    pause
    return
  fi

  local MEM_TOTAL
  MEM_TOTAL=$(free -m | awk '/^Mem:/ {print $2}')
  if [[ "$MEM_TOTAL" -gt "2048" ]]; then
    echo -e "  ${Y}⚠ Tu sistema tiene más de 2GB de RAM.${N}"
    echo -e "  ${W}No es estrictamente necesario crear swap, pero procediendo...${N}"
  fi

  echo -e "  ${Y}•${N} ${W}Creando swapfile de 2GB (esto puede tardar)...${N}"
  fallocate -l 2G "$swap" || dd if=/dev/zero of="$swap" bs=1M count=2048
  chmod 600 "$swap"
  mkswap "$swap" &>/dev/null
  swapon "$swap"
  
  # Agregar al fstab para que sea permanente por defecto
  if ! grep -q "$swap" "$fstab"; then
    echo "$swap none swap sw 0 0" >> "$fstab"
  fi
  
  echo -e "  ${G}✓ Swapfile de 2GB creado y activado.${N}"
  pause
}

funcion_prio() {
  clear_screen
  hr
  echo -e "${W}${BOLD}              PRIORIDAD DE SWAP (Swappiness)${N}"
  hr
  echo -e "  ${D}Define qué tan rápido el sistema usa la SWAP.${N}"
  echo -e "  ${D}Valores bajos = Prioriza RAM | Valores altos = Usa más SWAP.${N}"
  sep
  echo -e "  ${R}[${Y}1${R}]${N}  ${C}10 (Mínimo)${N}"
  echo -e "  ${R}[${Y}2${R}]${N}  ${C}20 (Recomendado VPS)${N}"
  echo -e "  ${R}[${Y}6${R}]${N}  ${C}60 (Default Linux)${N}"
  echo -e "  ${R}[${Y}10${R}]${N} ${C}100 (Máximo)${N}"
  sep
  echo -e "  ${R}[${Y}0${R}]${N}  ${W}VOLVER${N}"
  sep
  echo -ne "  ${W}Selecciona (1-10): ${G}"
  read -r op_prio

  if [[ "$op_prio" =~ ^[0-9]+$ ]] && [ "$op_prio" -ge 1 ] && [ "$op_prio" -le 10 ]; then
    local val=$((op_prio * 10))
    sed -i '/vm.swappiness/d' "$sysctl_conf"
    echo "vm.swappiness=$val" >> "$sysctl_conf"
    sysctl -p "$sysctl_conf" &>/dev/null || true
    echo -e "\n  ${G}✓ Prioridad establecida en: ${Y}$val${N}"
  elif [[ "$op_prio" == "0" ]]; then
    return
  else
    echo -e "  ${R}✗ Opción inválida${N}"
  fi
  pause
}

# ── Menú Principal ───────────────────────────────────────

main_menu() {
  while true; do
    clear_screen
    local SWAP_STATUS
    if swapon --show | grep -q "/"; then
        SWAP_STATUS="${G}ACTIVA${N}"
    else
        SWAP_STATUS="${R}INACTIVA${N}"
    fi

    hr
    echo -e "${W}${BOLD}              GESTIÓN DE MEMORIA SWAP${N}"
    hr
    echo -e "  ${W}ESTADO ACTUAL:${N} $SWAP_STATUS"
    hr
    echo ""
    echo -e "  ${R}[${Y}1${R}]${N}  ${C}CREAR / ELIMINAR SWAPFILE (2GB)${N}"
    echo -e "  ${R}[${Y}2${R}]${N}  ${C}AJUSTAR PRIORIDAD (SWAPPINESS)${N}"
    sep
    echo -e "  ${R}[${Y}0${R}]${N}  ${W}VOLVER${N}"
    hr
    echo ""
    echo -ne "  ${W}Selecciona una opción: ${G}"
    read -r option
    case "${option:-}" in
      1) funcion_crear ;;
      2) funcion_prio ;;
      0) break ;;
      *) echo -e "  ${R}Opción inválida${N}"; sleep 1 ;;
    esac
  done
}

# Ejecución
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo -e "${R}Error: Debes ser root.${N}"
  exit 1
fi

main_menu
