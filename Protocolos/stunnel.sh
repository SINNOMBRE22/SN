#!/bin/bash
set -euo pipefail

# =========================================================
# SinNombre v1.0 - STUNNEL (SSL) Estilo ADMRufu (Rufu99)
# Archivo: SN/Protocolos/stunnel.sh
#
# AJUSTES (2025-12-15):
# - Añade FIX opcional para "SSL lento": TCPMSS --clamp-mss-to-pmtu (iptables mangle)
#   * Idempotente (no duplica reglas)
#   * Opción de persistencia (iptables-persistent/netfilter-persistent)
# - Mejora detección de servicio inactivo usando systemctl is-active
# =========================================================

R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
B='\033[0;34m'
C='\033[0;36m'
W='\033[1;37m'
N='\033[0m'
D='\033[2m'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

pause(){ echo ""; read -r -p "Presiona Enter para continuar..."; }
hr(){ echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"; }
sep(){ echo -e "${R}------------------------------------------------------------${N}"; }

require_root(){ [[ "${EUID:-$(id -u)}" -eq 0 ]] || { echo -e "${R}Ejecuta como root.${N}"; exit 1; }; }

CONF="/etc/stunnel/stunnel.conf"
PEM="/etc/stunnel/stunnel.pem"
DEFAULTS="/etc/default/stunnel4"

DPB=""
declare -a drop

mportas() {
  ss -H -lnt 2>/dev/null | awk '{print $4}' | awk -F: '{print $NF}' | sort -n | uniq
}

is_installed(){
  dpkg -l 2>/dev/null | grep -qE '^[hi]i[[:space:]]+stunnel4'
}

is_on() {
  systemctl is-active --quiet stunnel4 2>/dev/null && return 0
  service stunnel4 status 2>/dev/null | grep -qi "active" && return 0
  return 1
}

show_ports(){
  local ports
  ports="$(ss -H -lntp 2>/dev/null | awk '$0 ~ /(stunnel|stunnel4)/ {print $4}' \
    | awk -F: '{print $NF}' | sort -n | uniq | tr '\n' ' ' | sed 's/[[:space:]]\+$//' || true)"
  [[ -n "${ports:-}" ]] && echo "$ports" || echo "Ninguno"
}

drop_port(){
  DPB=""
  local portasVAR
  portasVAR="$(lsof -V -i tcp -P -n 2>/dev/null | grep -v "ESTABLISHED" | grep -v "COMMAND" | grep "LISTEN" || true)"
  local NOREPEAT=""
  local reQ Port

  while read -r port; do
    [[ -z "${port:-}" ]] && continue
    reQ="$(echo "${port}" | awk '{print $1}')"
    Port="$(echo "${port}" | awk '{print $9}' | awk -F ":" '{print $2}')"
    [[ -z "${Port:-}" ]] && continue

    echo -e "$NOREPEAT" | grep -qw "$Port" && continue
    NOREPEAT+="$Port\n"

    case "${reQ}" in
      cupsd) continue ;;
      systemd-r) continue ;;
      stunnel4|stunnel) continue ;;
      *) DPB+=" ${reQ}:${Port}" ;;
    esac
  done <<< "${portasVAR}"
}

ensure_enabled(){
  [[ -f "$DEFAULTS" ]] || return 0
  if grep -q '^ENABLED=' "$DEFAULTS"; then
    sed -i 's/^ENABLED=.*/ENABLED=1/' "$DEFAULTS" 2>/dev/null || true
  else
    echo "ENABLED=1" >> "$DEFAULTS"
  fi
}

gen_pem(){
  [[ -f "$PEM" ]] && return 0
  mkdir -p /etc/stunnel >/dev/null 2>&1 || true

  local tmp="/tmp/sn_stunnel.$$"
  mkdir -p "$tmp"
  openssl genrsa -out "$tmp/stunnel.key" 2048 >/dev/null 2>&1
  (echo "" ; echo "" ; echo "" ; echo "" ; echo "" ; echo "" ; echo "@cloudflare") \
    | openssl req -new -key "$tmp/stunnel.key" -x509 -days 1000 -out "$tmp/stunnel.crt" >/dev/null 2>&1
  cat "$tmp/stunnel.key" "$tmp/stunnel.crt" > "$PEM"
  chmod 600 "$PEM" >/dev/null 2>&1 || true
  rm -rf "$tmp" >/dev/null 2>&1 || true
}

service_restart(){
  ensure_enabled
  service stunnel4 restart >/dev/null 2>&1 || systemctl restart stunnel4 >/dev/null 2>&1 || true
}

service_stop(){
  service stunnel4 stop >/dev/null 2>&1 || systemctl stop stunnel4 >/dev/null 2>&1 || true
}

service_start(){
  ensure_enabled
  service stunnel4 start >/dev/null 2>&1 || systemctl start stunnel4 >/dev/null 2>&1 || true
}

service_is_inactive(){
  systemctl is-active --quiet stunnel4 2>/dev/null && return 1
  return 0
}

# ==============================
# FIX SSL LENTO (MTU/MSS clamp)
# ==============================
mss_fix_is_applied() {
  iptables -t mangle -C POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu >/dev/null 2>&1
}

mss_fix_apply() {
  if mss_fix_is_applied; then
    echo -e "${Y}MSS clamp ya estaba aplicado.${N}"
    return 0
  fi
  iptables -t mangle -A POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
  echo -e "${G}MSS clamp aplicado (POSTROUTING TCP SYN).${N}"
}

mss_fix_persist() {
  if command -v netfilter-persistent >/dev/null 2>&1; then
    netfilter-persistent save >/dev/null 2>&1 || true
    echo -e "${G}Reglas guardadas (netfilter-persistent).${N}"
    return 0
  fi

  if command -v apt-get >/dev/null 2>&1; then
    apt-get update -y >/dev/null 2>&1 || true
    DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent >/dev/null 2>&1 || true
    if command -v netfilter-persistent >/dev/null 2>&1; then
      netfilter-persistent save >/dev/null 2>&1 || true
      echo -e "${G}Reglas guardadas (iptables-persistent).${N}"
      return 0
    fi
  fi

  echo -e "${Y}No se pudo dejar persistente automáticamente.${N}"
  echo -e "${Y}Aplicado en runtime; tras reinicio podría perderse.${N}"
  return 0
}

ask_apply_ssl_fix() {
  is_on || return 0

  echo ""
  sep
  echo -e "${W}FIX opcional para SSL lento:${N} clamp MSS a PMTU"
  echo -e "${D}Ayuda a evitar fragmentación (común en túneles SSL/TLS).${N}"

  if mss_fix_is_applied; then
    echo -e "${G}Estado actual:${N} ${Y}Ya aplicado${N}"
    sep
    return 0
  fi

  read -r -p "¿Aplicar fix recomendado ahora? (s/n): " yn
  if [[ "${yn,,}" == "s" ]]; then
    mss_fix_apply
    read -r -p "¿Hacerlo persistente tras reinicio? (s/n): " yn2
    [[ "${yn2,,}" == "s" ]] && mss_fix_persist
  fi
  sep
}

# -------------------------
# INSTALAR / DESINSTALAR
# -------------------------
ssl_stunel(){
  if is_installed; then
    clear
    hr
    echo -e "${Y}Parando y desinstalando Stunnel...${N}"
    hr
    service_stop
    apt-get purge -y stunnel4 >/dev/null 2>&1 || true
    hr
    echo -e "${G}Stunnel detenido/desinstalado con éxito!${N}"
    hr
    sleep 1
    pause
    return
  fi

  clear
  hr
  echo -e "${W}          INSTALADOR SSL By SinNombre${N}"
  hr
  echo -e "${C}Seleccione puerto de redireccion de trafico${N}"
  sep

  apt-get update -y >/dev/null 2>&1 || true
  apt-get install -y lsof >/dev/null 2>&1 || true

  drop_port
  local n=1 num_opc=0
  unset drop || true
  declare -a drop

  for i in $DPB; do
    local proto proto2 port
    proto="$(echo "$i" | awk -F ":" '{print $1}')"
    proto2="$(printf '%-12s' "$proto")"
    port="$(echo "$i" | awk -F ":" '{print $2}')"
    echo -e " ${G}[${n}]${N} ${W}>${N} ${C}${proto2}${N}${Y}${port}${N}"
    drop[$n]="$port"
    num_opc="$n"
    n=$((n+1))
  done

  sep
  [[ "$num_opc" -ge 1 ]] || { echo -e "${R}No hay puertos para redirigir.${N}"; pause; return; }

  local opc=""
  while [[ -z "${opc:-}" ]]; do
    read -r -p " opcion: " opc
    [[ "${opc:-}" =~ ^[0-9]+$ ]] || { echo -e "${R}Solo números.${N}"; opc=""; continue; }
    [[ -n "${drop[$opc]:-}" ]] || { echo -e "${R}Opción inválida.${N}"; opc=""; continue; }
  done

  clear
  hr
  echo -e "${W}Puerto de redireccion:${N} ${Y}${drop[$opc]}${N}"
  hr

  local opc2=""
  while [[ -z "${opc2:-}" ]]; do
    read -r -p " Ingrese un puerto para SSL: " opc2
    [[ "${opc2:-}" =~ ^[0-9]+$ ]] || { echo -e "${R}Puerto inválido.${N}"; opc2=""; continue; }
    if mportas | grep -qx "${opc2}"; then
      echo -e "${R}Puerto SSL ${opc2} en uso (FAIL).${N}"
      opc2=""
      continue
    fi
    echo -e "${G}Puerto SSL ${opc2} OK${N}"
  done

  sep
  echo -e "${W}Instalando stunnel4...${N}"
  sep
  apt-get install -y stunnel4 openssl >/dev/null 2>&1 || true

  gen_pem
  ensure_enabled

  echo -e "client = no\n[SSL]\ncert = /etc/stunnel/stunnel.pem\naccept = ${opc2}\nconnect = 127.0.0.1:${drop[$opc]}" > "$CONF"

  service_restart

  clear
  hr
  echo -e "${G}INSTALADO CON EXITO${N}"
  hr
  echo -e "${W}SSL:${N} ${Y}${opc2}${N}  ${W}-> REDIR:${N} ${Y}${drop[$opc]}${N}"
  hr

  ask_apply_ssl_fix
  pause
}

# -------------------------
# AGREGAR PUERTO
# -------------------------
add_port(){
  clear
  hr
  echo -e "${W}          AGREGAR PUERTOS SSL${N}"
  hr

  is_installed || { echo -e "${R}Stunnel no está instalado.${N}"; pause; return; }

  drop_port
  local n=1 num_opc=0
  unset drop || true
  declare -a drop

  for i in $DPB; do
    local proto proto2 port
    proto="$(echo "$i" | awk -F ":" '{print $1}')"
    proto2="$(printf '%-12s' "$proto")"
    port="$(echo "$i" | awk -F ":" '{print $2}')"
    echo -e " ${G}[${n}]${N} ${W}>${N} ${C}${proto2}${N}${Y}${port}${N}"
    drop[$n]="$port"
    num_opc="$n"
    n=$((n+1))
  done
  sep

  local opc=""
  while [[ -z "${opc:-}" ]]; do
    read -r -p " opcion: " opc
    [[ "${opc:-}" =~ ^[0-9]+$ ]] || { echo -e "${R}Solo números.${N}"; opc=""; continue; }
    [[ -n "${drop[$opc]:-}" ]] || { echo -e "${R}Opción inválida.${N}"; opc=""; continue; }
  done

  echo -e "${W}Puerto de redireccion:${N} ${Y}${drop[$opc]}${N}"
  sep

  local opc2=""
  while [[ -z "${opc2:-}" ]]; do
    read -r -p " Ingrese un puerto para SSL: " opc2
    [[ "${opc2:-}" =~ ^[0-9]+$ ]] || { echo -e "${R}Puerto inválido.${N}"; opc2=""; continue; }
    if mportas | grep -qx "${opc2}"; then
      echo -e "${R}Puerto ${opc2} en uso (FAIL).${N}"
      opc2=""
      continue
    fi
    echo -e "${G}Puerto SSL ${opc2} OK${N}"
  done

  gen_pem
  echo -e "client = no\n[SSL+]\ncert = /etc/stunnel/stunnel.pem\naccept = ${opc2}\nconnect = 127.0.0.1:${drop[$opc]}" >> "$CONF"

  service_restart
  ask_apply_ssl_fix

  clear
  hr
  echo -e "${G}PUERTO AGREGADO CON EXITO${N}"
  hr
  pause
}

# -------------------------
# INICIAR / PARAR
# -------------------------
start_stop(){
  clear
  hr
  if service_is_inactive; then
    if service_start; then
      echo -e "${G}Servicio stunnel4 iniciado${N}"
      ask_apply_ssl_fix
    else
      echo -e "${R}Falla al iniciar Servicio stunnel4${N}"
    fi
  else
    if service_stop; then
      echo -e "${Y}Servicio stunnel4 detenido${N}"
    else
      echo -e "${R}Falla al detener Servicio stunnel4${N}"
    fi
  fi
  hr
  pause
}

# -------------------------
# QUITAR PUERTO
# -------------------------
del_port(){
  clear
  hr
  echo -e "${W}          QUITAR PUERTOS SSL${N}"
  hr

  is_installed || { echo -e "${R}Stunnel no está instalado.${N}"; pause; return; }

  local sslport
  sslport="$(lsof -V -i tcp -P -n 2>/dev/null | grep -v "ESTABLISHED" | grep -v "COMMAND" | grep "LISTEN" | grep -E 'stunnel|stunnel4' || true)"

  if [[ "$(echo "$sslport" | wc -l)" -lt 2 ]]; then
    echo -e "${Y}Un solo puerto para eliminar.${N}"
    read -r -p "¿Desea detener el servicio? (s/n): " a
    [[ "${a,,}" == "s" ]] && service_stop
    pause
    return
  fi

  echo -e "${W}Seleccione el num de puerto a quitar:${N}"
  sep
  local n=1
  unset drop || true
  declare -a drop
  while read -r i; do
    local port
    port="$(echo "$i" | awk '{print $9}' | cut -d ':' -f2)"
    echo -e " ${G}[${n}]${N} ${W}>${N} ${Y}${port}${N}"
    drop[$n]="$port"
    n=$((n+1))
  done <<<"$(echo "$sslport")"
  sep

  local opc=""
  while [[ -z "${opc:-}" ]]; do
    read -r -p " opcion: " opc
    [[ "${opc:-}" =~ ^[0-9]+$ ]] || { opc=""; continue; }
    [[ -n "${drop[$opc]:-}" ]] || { opc=""; continue; }
  done

  local in en
  in=$(( $(grep -n "accept = ${drop[$opc]}" "$CONF" | head -n1 | cut -d ':' -f1) - 3 ))
  en=$(( in + 4 ))
  (( in < 1 )) && in=1
  sed -i "${in},${en}d" "$CONF" || true
  sed -i '2 s/\[SSL+\]/\[SSL\]/' "$CONF" 2>/dev/null || true

  service_restart
  ask_apply_ssl_fix

  clear
  hr
  echo -e "${G}Puerto ssl ${drop[$opc]} eliminado${N}"
  hr
  pause
}

# -------------------------
# EDITAR REDIRECCIÓN
# -------------------------
edit_port(){
  clear
  hr
  echo -e "${W}      EDITAR PUERTO DE REDIRECCION${N}"
  hr

  is_installed || { echo -e "${R}Stunnel no está instalado.${N}"; pause; return; }

  local sslport
  sslport="$(lsof -V -i tcp -P -n 2>/dev/null | grep -v "ESTABLISHED" | grep -v "COMMAND" | grep "LISTEN" | grep -E 'stunnel|stunnel4' || true)"
  [[ -n "${sslport:-}" ]] || { echo -e "${Y}No hay puertos SSL.${N}"; pause; return; }

  echo -e "${W}Seleccione el num de puerto a editar:${N}"
  sep
  local n=1
  unset drop || true
  declare -a drop
  while read -r i; do
    local port
    port="$(echo "$i" | awk '{print $9}' | cut -d ':' -f2)"
    echo -e " ${G}[${n}]${N} ${W}>${N} ${Y}${port}${N}"
    drop[$n]="$port"
    n=$((n+1))
  done <<<"$(echo "$sslport")"
  sep

  local opc=""
  while [[ -z "${opc:-}" ]]; do
    read -r -p " opcion: " opc
    [[ "${opc:-}" =~ ^[0-9]+$ ]] || { opc=""; continue; }
    [[ -n "${drop[$opc]:-}" ]] || { opc=""; continue; }
  done

  local in en
  in=$(( $(grep -n "accept = ${drop[$opc]}" "$CONF" | head -n1 | cut -d ':' -f1) + 1 ))
  en="$(sed -n "${in}p" "$CONF" | cut -d ':' -f2)"
  echo -e "${W}Configuracion actual:${N} ${Y}${drop[$opc]}${N} >>> ${C}${en}${N}"
  sep

  drop_port
  n=1
  unset drop || true
  declare -a drop
  for i in $DPB; do
    local port2 proto proto2
    port2="$(echo "$i" | awk -F ":" '{print $2}')"
    [[ "$port2" == "$en" ]] && continue
    proto="$(echo "$i" | awk -F ":" '{print $1}')"
    proto2="$(printf '%-12s' "$proto")"
    echo -e " ${G}[${n}]${N} ${W}>${N} ${C}${proto2}${N}${Y}${port2}${N}"
    drop[$n]="$port2"
    n=$((n+1))
  done
  sep

  opc=""
  while [[ -z "${opc:-}" ]]; do
    read -r -p " opcion: " opc
    [[ "${opc:-}" =~ ^[0-9]+$ ]] || { opc=""; continue; }
    [[ -n "${drop[$opc]:-}" ]] || { opc=""; continue; }
  done

  sed -i "${in}s/${en}/${drop[$opc]}/" "$CONF" || true
  service_restart
  ask_apply_ssl_fix

  clear
  hr
  echo -e "${G}Puerto de redirecion modificado${N}"
  hr
  pause
}

restart_srv(){
  clear
  hr
  service_restart
  echo -e "${G}Servicio stunnel4 reiniciado${N}"
  hr
  ask_apply_ssl_fix
  pause
}

edit_nano(){
  nano "$CONF"
  restart_srv
}

main_menu(){
  require_root

  while true; do
    clear
    local st ports mss
    st="$(is_on && echo -e "${G}[ON]${N}" || echo -e "${R}[OFF]${N}")"
    ports="$(show_ports)"
    mss="$(mss_fix_is_applied && echo -e "${G}MSS-FIX:ON${N}" || echo -e "${R}MSS-FIX:OFF${N}")"

    hr
    echo -e "${W}               ADMINISTRADOR STUNNEL${N}"
    hr
    echo -e "${R}[${N} ${W}PUERTOS:${N} ${Y}${ports}${N}"
    echo -e "${R}[${N} ${W}ESTADO:${N} ${st}   ${mss}"
    hr

    echo -e "${R}[${Y}1${R}]${N} ${C}INSTALAR / DESINSTALAR${N}"

    if is_installed; then
      sep
      echo -e "${R}[${Y}2${R}]${N} ${C}AGREGAR PUERTOS SSL${N}"
      echo -e "${R}[${Y}3${R}]${N} ${C}QUITAR PUERTOS SSL${N}"
      sep
      echo -e "${R}[${Y}4${R}]${N} ${C}EDITAR PUERTO DE REDIRECCION${N}"
      echo -e "${R}[${Y}5${R}]${N} ${C}EDITAR MANUAL (NANO)${N}"
      sep
      echo -e "${R}[${Y}6${R}]${N} ${C}INICIAR/PARAR SERVICIO SSL${N} ${st}"
      echo -e "${R}[${Y}7${R}]${N} ${C}REINICIAR SERVICIO SSL${N}"
      echo -e "${R}[${Y}8${R}]${N} ${C}APLICAR FIX SSL LENTO (MSS/MTU)${N} ${mss}"
    fi

    hr
    echo -e "${R}[${Y}0${R}]${N} ${W}VOLVER${N}"
    hr

    echo ""
    echo -ne "${W}Ingresa una opcion: ${G}"
    read -r op

    case "${op:-}" in
      1) ssl_stunel ;;
      2) add_port ;;
      3) del_port ;;
      4) edit_port ;;
      5) edit_nano ;;
      6) start_stop ;;
      7) restart_srv ;;
      8) ask_apply_ssl_fix; pause ;;
      0) bash "${ROOT_DIR}/Protocolos/menu.sh" ;;
      *) echo -e "${B}Opción inválida${N}"; sleep 1 ;;
    esac
  done
}

main_menu
