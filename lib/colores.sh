#!/bin/bash
# =========================================================
# SinNombre - Colores y utilidades compartidas
# Incluir con: source /etc/SN/lib/colors.sh
# =========================================================

# Colores ANSI
R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
B='\033[0;34m'
M='\033[0;35m'
C='\033[0;36m'
W='\033[1;37m'
N='\033[0m'
BOLD='\033[1m'

# Líneas decorativas
hr()  { echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"; }
sep() { echo -e "${R}──────────────────────────────────────────────────────────${N}"; }

# Mensajes rápidos
step() { printf " ${C}•${N} ${W}%s${N} " "$1"; }
ok()   { echo -e "${G}[OK]${N}"; }
fail() { echo -e "${R}[FAIL]${N}"; }

# Pausa estándar
pause() { echo ""; read -r -p "Presiona Enter para continuar..."; }

# Limpiar pantalla
clear_screen() { clear; }

# Verificar root
require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    clear_screen
    hr
    echo -e "${Y}Este script requiere permisos root.${N}"
    echo -e "${W}Usa:${N} ${C}sudo menu${N}  ${W}o${N}  ${C}sudo sn${N}"
    hr
    exit 1
  fi
}

# Header estándar para sub-menús
header() {
  clear_screen
  hr
  echo -e "${W}      $1${N}"
  hr
}

# Ejecutar módulo con validación
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
