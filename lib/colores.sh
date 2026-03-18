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
D='\033[2m'

# Líneas decorativas
# Líneas decorativas
hr()  { echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"; }
sep() { echo -e "${R}──────────────────────────────────────────────────────────${N}"; }

# Exportar para que los scripts en /tmp/ las vean
export -f hr
export -f sep


# Mensajes rápidos (estilo instalador)
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

# =========================================================
# Funciones estilo v2ray/Rufu (msg, title, enter, del, etc.)
# Usadas por: Sistema/v2ray.sh, Protocolos/v2ray.sh y otros
# =========================================================

msg() {
  case "$1" in
    -bar)   echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}" ;;
    -bar3)  echo -e "${R}──────────────────────────────────────────${N}" ;;
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

print_center() {
  case "$1" in
    -blu)   shift; echo -e "${C}$*${N}" ;;
    -ama)   shift; echo -e "${Y}$*${N}" ;;
    -verd)  shift; echo -e "${G}$*${N}" ;;
    -verm2) shift; echo -e "${R}$*${N}" ;;
    *)      shift; echo -e "$*" ;;
  esac
}

title() {
  clear
  msg -bar
  echo -e "${W} $* ${N}"
  msg -bar
}

enter() {
  echo ""
  read -r -p " Presione ENTER para continuar"
}

# del: borra N líneas del terminal
del() {
  local lines="${1:-1}"
  for ((i = 0; i < lines; i++)); do
    tput cuu1 2>/dev/null || true
    tput el 2>/dev/null || true
  done
}

# Volver al menú principal
back_to_main() {
  local root="${1:-/etc/SN}"
  [[ -f "${root}/menu" ]] && bash "${root}/menu" || exit 0
}

# Ejecutar protocolo (usado por Protocolos/menu.sh)
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
