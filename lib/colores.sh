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

eval "$(echo "IyEvYmluL2Jhc2gKIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KIyBTaW5Ob21icmUgLSBDb2xvcmVzIHkgdXRpbGlkYWRlcyBjb21wYXJ0aWRhcwojIEluY2x1aXIgY29uOiBzb3VyY2UgL2V0Yy9TTi9saWIvY29sb3Jlcy5zaAojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQoKIyBDb2xvcmVzIEFOU0kKUj0nXDAzM1swOzMxbScKRz0nXDAzM1swOzMybScKWT0nXDAzM1sxOzMzbScKQj0nXDAzM1swOzM0bScKTT0nXDAzM1swOzM1bScKQz0nXDAzM1swOzM2bScKVz0nXDAzM1sxOzM3bScKTj0nXDAzM1swbScKQk9MRD0nXDAzM1sxbScKRD0nXDAzM1sybScKCiMgTMOtbmVhcyBkZWNvcmF0aXZhcwojIEzDrW5lYXMgZGVjb3JhdGl2YXMKaHIoKSAgeyBlY2hvIC1lICIke1J94pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQIC8gLyAvIOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkCR7Tn0iOyB9CnNlcCgpIHsgZWNobyAtZSAiJHtSfeKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgCR7Tn0iOyB9CgojIE1lbnNhamVzIHLDoXBpZG9zIChlc3RpbG8gaW5zdGFsYWRvcikKc3RlcCgpIHsgcHJpbnRmICIgJHtDfeKAoiR7Tn0gJHtXfSVzJHtOfSAiICIkMSI7IH0Kb2soKSAgIHsgZWNobyAtZSAiJHtHfVtPS10ke059IjsgfQpmYWlsKCkgeyBlY2hvIC1lICIke1J9W0ZBSUxdJHtOfSI7IH0KCiMgUGF1c2EgZXN0w6FuZGFyCnBhdXNlKCkgeyBlY2hvICIiOyByZWFkIC1yIC1wICJQcmVzaW9uYSBFbnRlciBwYXJhIGNvbnRpbnVhci4uLiI7IH0KCiMgTGltcGlhciBwYW50YWxsYQpjbGVhcl9zY3JlZW4oKSB7IGNsZWFyOyB9CgojIFZlcmlmaWNhciByb290CnJlcXVpcmVfcm9vdCgpIHsKICBpZiBbWyAiJHtFVUlEOi0kKGlkIC11KX0iIC1uZSAwIF1dOyB0aGVuCiAgICBjbGVhcl9zY3JlZW4KICAgIGhyCiAgICBlY2hvIC1lICIke1l9RXN0ZSBzY3JpcHQgcmVxdWllcmUgcGVybWlzb3Mgcm9vdC4ke059IgogICAgZWNobyAtZSAiJHtXfVVzYToke059ICR7Q31zdWRvIG1lbnUke059ICAke1d9byR7Tn0gICR7Q31zdWRvIHNuJHtOfSIKICAgIGhyCiAgICBleGl0IDEKICBmaQp9CgojIEhlYWRlciBlc3TDoW5kYXIgcGFyYSBzdWItbWVuw7pzCmhlYWRlcigpIHsKICBjbGVhcl9zY3JlZW4KICBocgogIGVjaG8gLWUgIiR7V30gICAgICAkMSR7Tn0iCiAgaHIKfQoKIyBFamVjdXRhciBtw7NkdWxvIGNvbiB2YWxpZGFjacOzbgpydW5fbW9kdWxlKCkgewogIGxvY2FsIGJhc2VfZGlyPSIkezI6LSQoY2QgIiQoZGlybmFtZSAiJHtCQVNIX1NPVVJDRVsxXX0iKSIgJiYgcHdkKX0iCiAgbG9jYWwgcmVsPSIkMSIKICBsb2NhbCBwYXRoPSIkYmFzZV9kaXIvJHJlbCIKCiAgaWYgW1sgLWYgIiRwYXRoIiBdXTsgdGhlbgogICAgY2htb2QgK3ggIiRwYXRoIgogICAgYmFzaCAiJHBhdGgiCiAgICBjbGVhcl9zY3JlZW4KICBlbHNlCiAgICBlY2hvCiAgICBlY2hvIC1lICIke1l9TcOzZHVsbyBubyBkaXNwb25pYmxlOiR7Tn0gJHtDfSR7cmVsfSR7Tn0iCiAgICBlY2hvIC1lICIke1l9UnV0YSBlc3BlcmFkYToke059ICRwYXRoIgogICAgZWNobyAtZSAiJHtZfUVzdGFkbzoke059IEVuIGRlc2Fycm9sbG8uLi4iCiAgICBwYXVzZQogIGZpCn0KCiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CiMgRnVuY2lvbmVzIGVzdGlsbyB2MnJheS9SdWZ1IChtc2csIHRpdGxlLCBlbnRlciwgZGVsLCBldGMuKQojIFVzYWRhcyBwb3I6IFNpc3RlbWEvdjJyYXkuc2gsIFByb3RvY29sb3MvdjJyYXkuc2ggeSBvdHJvcwojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQoKbXNnKCkgewogIGNhc2UgIiQxIiBpbgogICAgLWJhcikgICBlY2hvIC1lICIke1J94pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQIC8gLyAvIOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkCR7Tn0iIDs7CiAgICAtYmFyMykgIGVjaG8gLWUgIiR7Un3ilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIAke059IiA7OwogICAgLW5henUpICBzaGlmdDsgZWNobyAtbmUgIiR7Q30kKiR7Tn0gIiA7OwogICAgLWJsdSkgICBzaGlmdDsgZWNobyAtZSAiJHtDfSQqJHtOfSIgOzsKICAgIC12ZXJkKSAgc2hpZnQ7IGVjaG8gLWUgIiR7R30kKiR7Tn0iIDs7CiAgICAtdmVybXwtdmVybTIpIHNoaWZ0OyBlY2hvIC1lICIke1J9JCoke059IiA7OwogICAgLWFtYSkgICBzaGlmdDsgZWNobyAtZSAiJHtZfSQqJHtOfSIgOzsKICAgIC1henUpICAgc2hpZnQ7IGVjaG8gLWUgIiR7Q30kKiR7Tn0iIDs7CiAgICAtbmUpICAgIHNoaWZ0OyBlY2hvIC1uZSAiJCoiIDs7CiAgICAqKSAgICAgIGVjaG8gLWUgIiQqIiA7OwogIGVzYWMKfQoKcHJpbnRfY2VudGVyKCkgewogIGNhc2UgIiQxIiBpbgogICAgLWJsdSkgICBzaGlmdDsgZWNobyAtZSAiJHtDfSQqJHtOfSIgOzsKICAgIC1hbWEpICAgc2hpZnQ7IGVjaG8gLWUgIiR7WX0kKiR7Tn0iIDs7CiAgICAtdmVyZCkgIHNoaWZ0OyBlY2hvIC1lICIke0d9JCoke059IiA7OwogICAgLXZlcm0yKSBzaGlmdDsgZWNobyAtZSAiJHtSfSQqJHtOfSIgOzsKICAgICopICAgICAgc2hpZnQ7IGVjaG8gLWUgIiQqIiA7OwogIGVzYWMKfQoKdGl0bGUoKSB7CiAgY2xlYXIKICBtc2cgLWJhcgogIGVjaG8gLWUgIiR7V30gJCogJHtOfSIKICBtc2cgLWJhcgp9CgplbnRlcigpIHsKICBlY2hvICIiCiAgcmVhZCAtciAtcCAiIFByZXNpb25lIEVOVEVSIHBhcmEgY29udGludWFyIgp9CgojIGRlbDogYm9ycmEgTiBsw61uZWFzIGRlbCB0ZXJtaW5hbApkZWwoKSB7CiAgbG9jYWwgbGluZXM9IiR7MTotMX0iCiAgZm9yICgoaSA9IDA7IGkgPCBsaW5lczsgaSsrKSk7IGRvCiAgICB0cHV0IGN1dTEgMj4vZGV2L251bGwgfHwgdHJ1ZQogICAgdHB1dCBlbCAyPi9kZXYvbnVsbCB8fCB0cnVlCiAgZG9uZQp9CgojIFZvbHZlciBhbCBtZW7DuiBwcmluY2lwYWwKYmFja190b19tYWluKCkgewogIGxvY2FsIHJvb3Q9IiR7MTotL2V0Yy9TTn0iCiAgW1sgLWYgIiR7cm9vdH0vbWVudSIgXV0gJiYgYmFzaCAiJHtyb290fS9tZW51IiB8fCBleGl0IDAKfQoKIyBFamVjdXRhciBwcm90b2NvbG8gKHVzYWRvIHBvciBQcm90b2NvbG9zL21lbnUuc2gpCnJ1bl9wcm90bygpIHsKICBsb2NhbCByb290X2Rpcj0iJDEiCiAgbG9jYWwgcmVsPSIkezItfSIKICBsb2NhbCBwYXRoPSIke3Jvb3RfZGlyfS8ke3JlbH0iCiAgaWYgW1sgLW4gIiR7cmVsfSIgJiYgLWYgIiRwYXRoIiBdXTsgdGhlbgogICAgYmFzaCAiJHBhdGgiCiAgZWxzZQogICAgZWNobyAiIgogICAgZWNobyAtZSAiJHtZfSR7Qk9MRH1Nw7NkdWxvIG5vIGRpc3BvbmlibGU6JHtOfSAke0N9JHtyZWw6LSIoc2luIHJ1dGEpIn0ke059IgogICAgZWNobyAtZSAiJHtEfUVzdGFkbzoke059ICR7WX1FbiBkZXNhcnJvbGxvLi4uJHtOfSIKICAgIHBhdXNlCiAgZmkKfQo=" | base64 -d)"
