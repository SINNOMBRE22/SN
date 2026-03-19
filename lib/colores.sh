#!/bin/bash
# =========================================================
# SN Plus - LIBRERÍA CENTRAL DE INTERFAZ (V2.1)
# =========================================================

CONFIG_TEMA="/root/SN/lib/tema.conf"

# --- 1. COLORES BASE PARA TEXTO ---
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; B='\033[0;34m'
M='\033[0;35m'; C='\033[0;36m'; W='\033[1;37m'; N='\033[0m'
BOLD='\033[1m'; D='\033[2m'

# --- 2. CARGA DEL TEMA DINÁMICO ---
if [[ -f "$CONFIG_TEMA" ]]; then
    source "$CONFIG_TEMA"
else
    L_COLOR='\033[38;2;0;255;255m' # Cian por defecto
fi

# --- 3. FUNCIONES DE DIBUJO ---
hr()  { echo -e "${L_COLOR}══════════════════════════ / / / ══════════════════════════${N}"; }
sep() { echo -e "${L_COLOR}──────────────────────────────────────────────────────────${N}"; }
clear_screen() { clear; }

# --- 4. UTILIDADES ---
step() { printf " ${C}•${N} ${W}%s${N} " "$1"; }
ok()   { echo -e "${G}[OK]${N}"; }
fail() { echo -e "${R}[FAIL]${N}"; }
pause() { echo ""; read -r -p "Presiona Enter para continuar..."; }
header() { clear_screen; hr; echo -e "${W}      $1${N}"; hr; }

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    clear_screen; hr
    echo -e "${Y}Este script requiere permisos root.${N}"
    exit 1
  fi
}

# --- 5. FUNCIÓN MSG (Etiquetas) ---
msg() {
  case "$1" in
    -bar)   hr ;;
    -bar3)  sep ;;
    -azu)   shift; echo -e "${C}$*${N}" ;;
    -verd)  shift; echo -e "${G}$*${N}" ;;
    -verm)  shift; echo -e "${R}$*${N}" ;;
    -ama)   shift; echo -e "${Y}$*${N}" ;;
    *)      echo -e "$*" ;;
  esac
}

