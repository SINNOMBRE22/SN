#!/bin/bash
set -euo pipefail

# =========================================================
# SinNombre v1.0 - GENERADOR DE USUARIOS (SSH/DROPBEAR/STUNNEL)
# Archivo: SN/Usuarios/generador.sh
# =========================================================

R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
B='\033[0;34m'
M='\033[0;35m'
C='\033[0;36m'
W='\033[1;37m'
N='\033[0m'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

pause() { echo ""; read -r -p "Presiona Enter para continuar..."; }

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo -e "${R}Ejecuta como root.${N}"
    exit 1
  fi
}

hr() { echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"; }

DB="/etc/sn/panel_users.db"
ensure_db() { mkdir -p /etc/sn >/dev/null 2>&1 || true; touch "$DB" >/dev/null 2>&1 || true; }

server_ip() {
  curl -fsS --max-time 2 ifconfig.me 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}' || echo "0.0.0.0"
}

ssh_ports() {
  local ports=""
  ports="$(ss -H -lntp 2>/dev/null | awk '$0 ~ /(sshd|ssh)/ {print $4}' | awk -F: '{print $NF}' | sort -n | uniq | tr '\n' ' ' | sed 's/[[:space:]]\+$//' || true)"
  [[ -n "${ports:-}" ]] && echo "$ports" || echo "22"
}

dropbear_ports() {
  local ports=""
  ports="$(ss -H -lntp 2>/dev/null | awk '$0 ~ /dropbear/ {print $4}' | awk -F: '{print $NF}' | sort -n | uniq | tr '\n' ' ' | sed 's/[[:space:]]\+$//' || true)"
  [[ -n "${ports:-}" ]] && echo "$ports" || echo "-"
}

stunnel_ports() {
  local ports=""
  ports="$(ss -H -lntp 2>/dev/null | awk '$0 ~ /stunnel4/ {print $4}' | awk -F: '{print $NF}' | sort -n | uniq | tr '\n' ' ' | sed 's/[[:space:]]\+$//' || true)"
  [[ -n "${ports:-}" ]] && echo "$ports" || echo "-"
}

valid_user() {
  [[ "$1" =~ ^[a-zA-Z0-9._-]{3,32}$ ]]
}

create_user() {
  clear
  hr
  echo -e "${W}              GENERAR USUARIO SSH${N}"
  hr

  read -r -p "Usuario: " u
  valid_user "${u:-}" || { echo -e "${R}Usuario inválido (3-32, letras/números/._-).${N}"; pause; return; }

  if id "$u" >/dev/null 2>&1; then
    echo -e "${Y}El usuario ya existe.${N}"
    pause
    return
  fi

  read -r -s -p "Contraseña: " p; echo ""
  [[ -n "${p:-}" ]] || { echo -e "${R}Contraseña vacía.${N}"; pause; return; }

  read -r -p "Duración en días (ej 1,7,30): " days
  [[ "${days:-}" =~ ^[0-9]+$ ]] || { echo -e "${R}Días inválidos.${N}"; pause; return; }
  (( days >= 1 && days <= 3650 )) || { echo -e "${R}Rango inválido (1-3650).${N}"; pause; return; }

  local exp_date
  exp_date="$(date -d "+${days} days" +%Y-%m-%d)"

  # Crear usuario sin shell interactiva
  useradd -m -s /usr/sbin/nologin -e "$exp_date" "$u"
  echo "${u}:${p}" | chpasswd

  ensure_db
  printf "%s|%s|%s\n" "$u" "$exp_date" "$(date +%F)" >>"$DB"

  # Ticket
  local ip sshp dbp stp
  ip="$(server_ip)"
  sshp="$(ssh_ports)"
  dbp="$(dropbear_ports)"
  stp="$(stunnel_ports)"

  clear
  hr
  echo -e "${W}                CUENTA CREADA${N}"
  hr
  echo -e "${W}IP:${N} ${Y}${ip}${N}"
  echo -e "${W}USUARIO:${N} ${Y}${u}${N}"
  echo -e "${W}CONTRASEÑA:${N} ${Y}${p}${N}"
  echo -e "${W}EXPIRA:${N} ${Y}${exp_date}${N}"
  hr
  echo -e "${W}SSH:${N} ${Y}${sshp}${N}"
  echo -e "${W}DROPBEAR:${N} ${Y}${dbp}${N}"
  echo -e "${W}SSL (STUNNEL):${N} ${Y}${stp}${N}"
  hr

  pause
}

list_panel_users() {
  clear
  hr
  echo -e "${W}           USUARIOS CREADOS POR EL PANEL${N}"
  hr

  ensure_db
  if [[ ! -s "$DB" ]]; then
    echo -e "${Y}Aún no hay usuarios registrados.${N}"
    pause
    return
  fi

  # Mostrar solo los que siguen existiendo
  while IFS='|' read -r u exp created; do
    [[ -z "${u:-}" ]] && continue
    if id "$u" >/dev/null 2>&1; then
      echo -e "${C}${u}${N}  ${W}Exp:${N} ${Y}${exp}${N}  ${W}Creado:${N} ${Y}${created}${N}"
    else
      echo -e "${R}${u}${N}  ${Y}(ya no existe en el sistema)${N}"
    fi
  done <"$DB"

  pause
}

delete_user() {
  clear
  hr
  echo -e "${W}              ELIMINAR USUARIO${N}"
  hr

  read -r -p "Usuario a eliminar: " u
  [[ -n "${u:-}" ]] || { echo -e "${R}Vacío.${N}"; pause; return; }

  if ! id "$u" >/dev/null 2>&1; then
    echo -e "${Y}El usuario no existe.${N}"
    pause
    return
  fi

  read -r -p "¿Confirmas eliminar ${u}? (s/n): " yn
  [[ "${yn,,}" == "s" ]] || { echo "Cancelado."; pause; return; }

  userdel -r "$u" >/dev/null 2>&1 || userdel "$u" >/dev/null 2>&1 || true

  # limpiar DB
  ensure_db
  if [[ -s "$DB" ]]; then
    grep -vE "^${u}\|" "$DB" > "${DB}.tmp" || true
    mv "${DB}.tmp" "$DB" >/dev/null 2>&1 || true
  fi

  echo -e "${G}Usuario eliminado.${N}"
  pause
}

main_menu() {
  require_root
  ensure_db

  while true; do
    clear
    hr
    echo -e "${W}            GENERADOR DE USUARIOS (SSH)${N}"
    hr

    echo -e "${R}[${Y}1${R}]${N} ${C}CREAR USUARIO${N}"
    echo -e "${R}[${Y}2${R}]${N} ${C}LISTAR USUARIOS DEL PANEL${N}"
    echo -e "${R}[${Y}3${R}]${N} ${C}ELIMINAR USUARIO${N}"
    echo -e "${R}[${Y}0${R}]${N} ${W}VOLVER${N}"

    hr
    echo ""
    echo -ne "${W}Ingresa una Opcion: ${G}"
    read -r op

    case "${op:-}" in
      1) create_user ;;
      2) list_panel_users ;;
      3) delete_user ;;
      0)
        # vuelve al menú principal del panel si existe
        [[ -f "${ROOT_DIR}/menu" ]] && bash "${ROOT_DIR}/menu" || exit 0
        ;;
      *) echo -e "${B}Opción inválida${N}"; sleep 1 ;;
    esac
  done
}

main_menu
