#!/bin/bash
# =========================================================
# SN Plus - LIBRERÍA CENTRAL DE INTERFAZ (ANSI)
# Compatible con JuiceSSH y terminales básicas
# =========================================================

# --- 0. DETECCIÓN DE UBICACIÓN DE LA LIBRERÍA ---
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_PANEL="$(dirname "$LIB_DIR")"
CONFIG_TEMA="$LIB_DIR/tema.conf"

# --- 1. COLORES BASE ANSI (16 colores estándar) ---
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; B='\033[0;34m'
M='\033[0;35m'; C='\033[0;36m'; W='\033[1;37m'; N='\033[0m'
BOLD='\033[1m'; D='\033[2m'

# --- 2. CARGA DEL TEMA DINÁMICO (debe ser un código ANSI) ---
if [[ -f "$CONFIG_TEMA" ]]; then
    source "$CONFIG_TEMA"
else
    L_COLOR="$C"   # Cian por defecto (ANSI)
fi

# --- 3. FUNCIONES DE DIBUJO (usando L_COLOR) ---
hr()  { echo -e "${L_COLOR}══════════════════════════ / / / ══════════════════════════${N}"; }
sep() { echo -e "${L_COLOR}──────────────────────────────────────────────────────────${N}"; }
clear_screen() { clear; }

# --- 4. UTILIDADES BÁSICAS ---
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

# --- 5. FUNCIÓN MSG COMPLETA ---
msg() {
  case "$1" in
    -bar)   hr ;;
    -bar3)  sep ;;
    -nazu)  shift; echo -ne "${C}$*${N} " ;;
    -blu)   shift; echo -e "${C}$*${N}" ;;
    -verd)  shift; echo -e "${G}$*${N}" ;;
    -verm|-verm2) shift; echo -e "${R}$*${N}" ;;
    -ama)   shift; echo -e "${Y}$*${N}" ;;
    -azu)   shift; echo -e "${C}$*${N}" ;;
    -ne)    shift; echo -ne "$*" ;;
    *)      echo -e "$*" ;;
  esac
}

# --- 6. FUNCIÓN PRINT_CENTER (simple, sin centrado) ---
print_center() {
  case "$1" in
    -blu)   shift; echo -e "${C}$*${N}" ;;
    -ama)   shift; echo -e "${Y}$*${N}" ;;
    -verd)  shift; echo -e "${G}$*${N}" ;;
    -verm2) shift; echo -e "${R}$*${N}" ;;
    *)      echo -e "$*" ;;
  esac
}

# --- 7. FUNCIÓN TITLE ---
title() {
  clear_screen
  hr
  echo -e "${W}    $* ${N}"
  hr
}

# --- 8. FUNCIÓN ENTER ---
enter() {
  echo ""
  read -r -p " Presione ENTER para continuar"
}

# --- 9. FUNCIÓN DEL ---
del() {
  local lines="${1:-1}"
  for ((i = 0; i < lines; i++)); do
    tput cuu1 2>/dev/null || true
    tput el 2>/dev/null || true
  done
}

# --- 10. FUNCIONES AUXILIARES ---
back_to_main() {
  local root="${1:-$ROOT_PANEL}"
  [[ -f "${root}/menu" ]] && bash "${root}/menu" || exit 0
}

run_proto() {
  local root_dir="$1"
  local rel="${2-}"
  local path="${root_dir}/${rel}"
  if [[ -n "${rel}" && -f "$path" ]]; then
    bash "$path"
  else
    echo ""
    echo -e "${Y}${BOLD}Módulo no disponible:${N} ${C}${rel:-"(sin ruta)"}${N}"
    echo -e "${D}Estado:${N} ${Y}En desarrollo...${N}"
    pause
  fi
}

run_module() {
  local base_dir="${2:-$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)}"
  local rel="$1"
  local path="$base_dir/$rel"

  if [[ -f "$path" ]]; then
    chmod +x "$path"
    bash "$path"
    clear_screen
  else
    echo
    echo -e "${Y}Módulo no disponible:${N} ${C}${rel}${N}"
    echo -e "${Y}Ruta esperada:${N} $path"
    echo -e "${Y}Estado:${N} En desarrollo..."
    pause
  fi
}
