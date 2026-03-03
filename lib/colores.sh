#!/bin/bash
# =========================================================
# SinNombre - Colores y utilidades compartidas
# Incluir con: source /etc/SN/lib/colores.sh
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

# Línea horizontal (alias de hr)
line() { echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"; }

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

# Ejecutar protocolo con validación (usado en Protocolos/menu.sh)
run_proto() {
  local root_dir="${2:-$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)}"
  local rel="${1-}"
  local path="${root_dir}/${rel}"
  if [[ -n "${rel}" && -f "$path" ]]; then
    bash "$path"
  else
    echo ""
    echo -e "${Y}${BOLD}Módulo no disponible:${N} ${C}${rel:-"(sin ruta)"}${N}"
    echo -e "Estado: ${Y}En desarrollo...${N}"
    pause
  fi
}

# Volver al menú principal
back_to_main() {
  local root_dir="${1:-$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)}"
  [[ -f "${root_dir}/menu" ]] && bash "${root_dir}/menu" || exit 0
}

# Mensajes con estilo (compatibles con Sistema/v2ray.sh y otros)
msg() {
  case "$1" in
    -bar)   echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}" ;;
    -bar3)  echo -e "${R}──────────────────────────────────────────${N}" ;;
    -verd)  echo -e "${G}$2${N}" ;;
    -verm|-verm2) echo -e "${R}$2${N}" ;;
    -ama)   echo -e "${Y}$2${N}" ;;
    -azu)   echo -e "${C}$2${N}" ;;
    -ne)    echo -ne "$2" ;;
    -nazu)  echo -ne "${C}$2${N}" ;;
    -blu)   echo -e "${B}$2${N}" ;;
    *)      echo -e "$*" ;;
  esac
}

# Título de sección
title() {
  clear
  msg -bar
  echo -e "${W} $* ${N}"
  msg -bar
}

# Imprimir centrado (delegado a msg)
print_center() {
  msg "$1" "$2"
}

# Pausa con Enter
enter() {
  read -rp " Presione ENTER para continuar"
}

# Borrar N líneas del terminal
del() {
  local n="${1:-1}"
  if command -v tput >/dev/null 2>&1 && [[ -t 1 ]]; then
    for ((i=0; i<n; i++)); do tput cuu1 && tput dl1; done
  fi
}
