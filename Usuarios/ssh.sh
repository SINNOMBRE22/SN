#!/bin/bash
set -euo pipefail

# =========================================================
# SinNombre v1.0 - USUARIOS SSH (estilo ADMRufu userSSH)
# Archivo: SN/Usuarios/ssh.sh
# Lógica:
# - useradd -M -s /bin/false -p <hash> -c LIMIT,PASS USER
# - chage -E <fecha>
# - Lista usuarios filtrando /etc/passwd por home + false (similar)
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
hr() { echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"; }

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo -e "${R}Ejecuta como root.${N}"
    exit 1
  fi
}

server_ip() {
  curl -fsS --max-time 2 ifconfig.me 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}' || echo "0.0.0.0"
}

ports_by_proc() {
  local re="$1"
  ss -H -lntp 2>/dev/null | awk -v r="$re" '$0 ~ r {print $4}' | awk -F: '{print $NF}' | sort -n | uniq | tr '\n' ' ' | sed 's/[[:space:]]\+$//' || true
}
ssh_ports() { local p; p="$(ports_by_proc '(sshd|ssh)')"; [[ -n "${p:-}" ]] && echo "$p" || echo "22"; }
dropbear_ports() { local p; p="$(ports_by_proc '(dropbear)')"; [[ -n "${p:-}" ]] && echo "$p" || echo "-"; }
stunnel_ports() { local p; p="$(ports_by_proc '(stunnel4)')"; [[ -n "${p:-}" ]] && echo "$p" || echo "-"; }

valid_user() { [[ "$1" =~ ^[a-zA-Z0-9._-]{4,20}$ ]]; }

openssl_hash() {
  # Igual idea que ADMRufu: según versión, usa -6 o -1
  local pass="$1"
  local ver
  ver="$(openssl version 2>/dev/null | awk '{print $2}' | cut -c1-5 || true)"
  if [[ "$ver" == "1.1.1" ]]; then
    openssl passwd -6 "$pass"
  else
    openssl passwd -1 "$pass"
  fi
}

# Usuarios tipo panel: home + false (similar al filtro del script)
list_users_raw() {
  cat /etc/passwd \
    | grep 'home' \
    | grep 'false' \
    | grep -v 'syslog' \
    | grep -v '::/' \
    | grep -v 'hwid\|token' \
    | sort || true
}

show_users() {
  clear
  hr
  echo -e "${W}                USUARIOS SSH REGISTRADOS${N}"
  hr

  local users
  users="$(list_users_raw)"
  if [[ -z "${users:-}" ]]; then
    echo -e "${Y}NO HAY USUARIOS SSH REGISTRADOS${N}"
    pause
    return
  fi

  # Encabezado
  printf "%b\n" "${C}Usuario         Pass         Expira       Días  Limit  Statu${N}"
  echo -e "${R}------------------------------------------------------------${N}"

  local i=1
  while IFS= read -r line; do
    local u limit pass fecha stat dias_left

    u="$(echo "$line" | awk -F: '{print $1}')"

    # comment/GECOS: LIMIT,PASS
    limit="$(echo "$line" | awk -F: '{print $5}' | cut -d',' -f1)"
    pass="$(echo "$line" | awk -F: '{print $5}' | cut -d',' -f2)"
    [[ ${#pass} -gt 12 ]] && pass="Desconocida"
    [[ -z "${limit:-}" ]] && limit="0"
    [[ -z "${pass:-}" ]] && pass="?"

    # status lock/unlock
    if [[ "$(passwd --status "$u" 2>/dev/null | awk '{print $2}')" == "P" ]]; then
      stat="ULK"
    else
      stat="LOK"
    fi

    # Fecha exp
    fecha="$(chage -l "$u" 2>/dev/null | sed -n '4p' | awk -F': ' '{print $2}' || true)"
    if [[ -z "${fecha:-}" || "${fecha,,}" == "never" || "${fecha,,}" == "nunca" ]]; then
      dias_left="N/A"
    else
      if date -d "${fecha}" >/dev/null 2>&1; then
        local now exp
        now="$(date +%s)"
        exp="$(date -d "${fecha}" +%s)"
        if (( now > exp )); then
          dias_left="Exp"
        else
          dias_left="$(( (exp - now) / 86400 ))"
        fi
      else
        dias_left="?"
      fi
    fi

    printf "%b\n" "$(printf "%-14s %-12s %-11s %-4s %-6s %s" "$u" "$pass" "${fecha:-N/A}" "$dias_left" "$limit" "$stat")"
    i=$((i+1))
  done <<< "$users"

  pause
}

create_user() {
  clear
  hr
  echo -e "${W}                 CREAR USUARIO SSH${N}"
  hr

  local u p days limit
  read -r -p "Usuario (4-20): " u
  valid_user "${u:-}" || { echo -e "${R}Usuario inválido.${N}"; pause; return; }

  if id "$u" >/dev/null 2>&1; then
    echo -e "${Y}Usuario ya existe.${N}"
    pause
    return
  fi

  read -r -p "Contraseña (4-12): " p
  [[ -n "${p:-}" && ${#p} -ge 4 && ${#p} -le 12 ]] || { echo -e "${R}Contraseña inválida.${N}"; pause; return; }

  read -r -p "Días duración (1-360): " days
  [[ "${days:-}" =~ ^[0-9]+$ ]] || { echo -e "${R}Días inválidos.${N}"; pause; return; }
  (( days >= 1 && days <= 360 )) || { echo -e "${R}Máximo 360 días.${N}"; pause; return; }

  read -r -p "Límite conexión (1-999): " limit
  [[ "${limit:-}" =~ ^[0-9]+$ ]] || { echo -e "${R}Límite inválido.${N}"; pause; return; }
  (( limit >= 1 && limit <= 999 )) || { echo -e "${R}Máximo 999.${N}"; pause; return; }

  local valid_date hash
  valid_date="$(date '+%C%y-%m-%d' -d " +${days} days")"
  hash="$(openssl_hash "$p")"

  # Igual que ADMRufu: sin home, shell false, comment con limit,pass
  useradd -M -s /bin/false -p "${hash}" -c "${limit},${p}" "${u}" >/dev/null 2>&1 || {
    echo -e "${R}Error: no se pudo crear usuario.${N}"
    pause
    return
  }

  chage -E "${valid_date}" -W 0 "${u}" >/dev/null 2>&1 || true

  # Ticket
  local ip sshp dbp stp
  ip="$(server_ip)"
  sshp="$(ssh_ports)"
  dbp="$(dropbear_ports)"
  stp="$(stunnel_ports)"

  clear
  hr
  echo -e "${W}                USUARIO CREADO CON ÉXITO${N}"
  hr
  echo -e "${W}IP:${N} ${Y}${ip}${N}"
  echo -e "${W}Usuario:${N} ${Y}${u}${N}"
  echo -e "${W}Contraseña:${N} ${Y}${p}${N}"
  echo -e "${W}Días:${N} ${Y}${days}${N}"
  echo -e "${W}Límite:${N} ${Y}${limit}${N}"
  echo -e "${W}Expira:${N} ${Y}$(date "+%F" -d " + ${days} days")${N}"
  hr
  echo -e "${W}SSH:${N} ${Y}${sshp}${N}"
  echo -e "${W}DROPBEAR:${N} ${Y}${dbp}${N}"
  echo -e "${W}SSL (STUNNEL):${N} ${Y}${stp}${N}"
  hr
  pause
}

renew_user() {
  clear
  hr
  echo -e "${W}                 RENOVAR USUARIO${N}"
  hr

  read -r -p "Usuario: " u
  id "$u" >/dev/null 2>&1 || { echo -e "${R}No existe.${N}"; pause; return; }

  read -r -p "Nuevos días (1-360): " days
  [[ "${days:-}" =~ ^[0-9]+$ ]] || { echo -e "${R}Días inválidos.${N}"; pause; return; }
  (( days >= 1 && days <= 360 )) || { echo -e "${R}Máximo 360.${N}"; pause; return; }

  local valid_date
  valid_date="$(date '+%C%y-%m-%d' -d " +${days} days")"
  chage -E "${valid_date}" "$u" >/dev/null 2>&1 || { echo -e "${R}Error renovando.${N}"; pause; return; }

  # si estaba bloqueado, opcional desbloquear
  if [[ "$(passwd --status "$u" 2>/dev/null | awk '{print $2}')" == "L" ]]; then
    read -r -p "Está bloqueado. ¿Desbloquear? (s/n): " yn
    [[ "${yn,,}" == "s" ]] && usermod -U "$u" >/dev/null 2>&1 || true
  fi

  echo -e "${G}Usuario renovado.${N}"
  pause
}

edit_user() {
  clear
  hr
  echo -e "${W}                 EDITAR USUARIO${N}"
  hr

  read -r -p "Usuario: " u
  id "$u" >/dev/null 2>&1 || { echo -e "${R}No existe.${N}"; pause; return; }

  read -r -p "Nueva contraseña (4-12): " p
  [[ -n "${p:-}" && ${#p} -ge 4 && ${#p} -le 12 ]] || { echo -e "${R}Contraseña inválida.${N}"; pause; return; }

  read -r -p "Nuevos días (1-360): " days
  [[ "${days:-}" =~ ^[0-9]+$ ]] || { echo -e "${R}Días inválidos.${N}"; pause; return; }
  (( days >= 1 && days <= 360 )) || { echo -e "${R}Máximo 360.${N}"; pause; return; }

  read -r -p "Nuevo límite (1-999): " limit
  [[ "${limit:-}" =~ ^[0-9]+$ ]] || { echo -e "${R}Límite inválido.${N}"; pause; return; }
  (( limit >= 1 && limit <= 999 )) || { echo -e "${R}Máximo 999.${N}"; pause; return; }

  local valid_date hash
  valid_date="$(date '+%C%y-%m-%d' -d " +${days} days")"
  hash="$(openssl_hash "$p")"

  # Actualiza pass hash + expiración + comment limit,pass
  usermod -p "${hash}" -c "${limit},${p}" "$u" >/dev/null 2>&1 || { echo -e "${R}Error modificando.${N}"; pause; return; }
  chage -E "${valid_date}" "$u" >/dev/null 2>&1 || true

  echo -e "${G}Usuario modificado.${N}"
  pause
}

lock_unlock_user() {
  clear
  hr
  echo -e "${W}             BLOQUEAR / DESBLOQUEAR USUARIO${N}"
  hr

  read -r -p "Usuario: " u
  id "$u" >/dev/null 2>&1 || { echo -e "${R}No existe.${N}"; pause; return; }

  if [[ "$(passwd --status "$u" 2>/dev/null | awk '{print $2}')" == "P" ]]; then
    pkill -u "$u" >/dev/null 2>&1 || true
    usermod -L "$u" >/dev/null 2>&1 || true
    echo -e "${Y}Bloqueado.${N}"
  else
    usermod -U "$u" >/dev/null 2>&1 || true
    echo -e "${G}Desbloqueado.${N}"
  fi
  pause
}

delete_user() {
  clear
  hr
  echo -e "${W}                 ELIMINAR USUARIO${N}"
  hr

  read -r -p "Usuario: " u
  id "$u" >/dev/null 2>&1 || { echo -e "${R}No existe.${N}"; pause; return; }

  read -r -p "¿Confirmas eliminar ${u}? (s/n): " yn
  [[ "${yn,,}" == "s" ]] || { echo "Cancelado."; pause; return; }

  pkill -u "$u" >/dev/null 2>&1 || true
  userdel --force "$u" >/dev/null 2>&1 || true
  echo -e "${G}Eliminado.${N}"
  pause
}

main_menu() {
  require_root

  while true; do
    clear
    hr
    echo -e "${W}               USUARIOS SSH (ESTILO ADMRufu)${N}"
    hr

    echo -e "${R}[${Y}1${R}]${N} ${C}CREAR USUARIO${N}"
    echo -e "${R}[${Y}2${R}]${N} ${C}LISTAR USUARIOS SSH${N}"
    echo -e "${R}[${Y}3${R}]${N} ${C}RENOVAR USUARIO${N}"
    echo -e "${R}[${Y}4${R}]${N} ${C}EDITAR USUARIO (PASS/DÍAS/LÍMITE)${N}"
    echo -e "${R}[${Y}5${R}]${N} ${C}BLOQUEAR/DESBLOQUEAR USUARIO${N}"
    echo -e "${R}[${Y}6${R}]${N} ${C}ELIMINAR USUARIO${N}"
    echo -e "${R}[${Y}0${R}]${N} ${W}VOLVER${N}"

    hr
    echo ""
    echo -ne "${W}Ingresa una Opcion: ${G}"
    read -r op

    case "${op:-}" in
      1) create_user ;;
      2) show_users ;;
      3) renew_user ;;
      4) edit_user ;;
      5) lock_unlock_user ;;
      6) delete_user ;;
      0) [[ -f "${ROOT_DIR}/menu" ]] && bash "${ROOT_DIR}/menu" || exit 0 ;;
      *) echo -e "${B}Opción inválida${N}"; sleep 1 ;;
    esac
  done
}

main_menu
