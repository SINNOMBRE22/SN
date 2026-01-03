#!/bin/bash
set -euo pipefail

# =========================================================
# SinNombre v1.0 - SLOWDNS (DNS Tunnel) Estilo ADMRufu (Rufu99)
# Archivo: SN/Protocolos/slowdns.sh
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

VPS_slow="/etc/SN/slowdns"
VPS_inst="/etc/SN"
mkdir -p "$VPS_slow" >/dev/null 2>&1

mportas() {
  ss -H -lnt 2>/dev/null | awk '{print $4}' | awk -F: '{print $NF}' | sort -n | uniq
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
      sshd|dropbear|stunnel4|stunnel|python|python3) DPB+=" ${reQ}:${Port}" ;;
      *) continue ;;
    esac
  done <<< "${portasVAR}"
}

info(){
  clear
  hr
  echo -e "${W}          DATOS DE SU CONECCION SLOWDNS${N}"
  hr

  local ns="" key=""
  if [[ -e "${VPS_slow}/domain_ns" ]]; then
    ns="$(cat "${VPS_slow}/domain_ns")"
  fi
  if [[ -e "${VPS_slow}/server.pub" ]]; then
    key="$(cat "${VPS_slow}/server.pub")"
  fi

  if [[ -z "$ns" || -z "$key" ]]; then
    echo -e "${Y}SIN INFORMACION SLOWDNS!!!${N}"
    pause
    return
  fi

  echo -e "${Y}Su NS (Nameserver): ${G}$ns${N}"
  hr
  echo -e "${Y}Su Llave: ${G}$key${N}"
  pause
}

ini_slow(){
  clear
  hr
  echo -e "${W}          INSTALADOR SLOWDNS By SinNombre${N}"
  hr
  echo -e "${C}Seleccione puerto de redireccion${N}"
  sep

  drop_port
  local n=1 num_opc=0
  unset drop || true
  declare -a drop

  for i in $DPB; do
    local proto proto2 port
    proto="$(echo "$i" | awk -F ":" '{print $1}')"
    proto2="$(printf '%-12s' "$proto")"
    port="$(echo "$i" | awk -F ":" '{print $2}')"
    echo -e " ${G}[$n]${N} ${W}>${N} ${C}${proto2}${N}${Y}${port}${N}"
    drop[$n]="$port"
    num_opc="$n"
    ((n++))
  done
  sep

  local opc=""
  while [[ -z "${opc:-}" ]]; do
    echo -ne "${W}Opcion: ${G}"
    read -r opc
    [[ "${opc:-}" =~ ^[0-9]+$ ]] || { echo -e "${R}Solo números.${N}"; opc=""; continue; }
    [[ -n "${drop[$opc]:-}" ]] || { echo -e "${R}Opción inválida.${N}"; opc=""; continue; }
  done

  echo "${drop[$opc]}" > "${VPS_slow}/puerto"
  PORT="$(cat "${VPS_slow}/puerto")"
  clear
  hr
  echo -e "${W}INSTALADOR SLOWDNS By SinNombre${N}"
  hr
  echo -e "${Y}Puerto de coneccion a traves de SlowDNS: ${G}$PORT${N}"
  hr

  local NS=""
  while [[ -z "$NS" ]]; do
    echo -ne "${W}Tu dominio NS: ${G}"
    read -r NS
    tput cuu1 && tput dl1
  done
  echo "$NS" > "${VPS_slow}/domain_ns"
  echo -e "${Y}Tu dominio NS: ${G}$NS${N}"
  hr

  if [[ ! -e "${VPS_inst}/dns-server" ]]; then
    echo -ne "${W}Descargando binario....${N}"
    if wget -O "${VPS_inst}/dns-server" https://github.com/SINNOMBRE22/VPS-SN/raw/main/utilidades/SlowDNS/dns-server &>/dev/null; then
      chmod +x "${VPS_inst}/dns-server"
      echo -e "${G}[OK]${N}"
    else
      echo -e "${R}[fail]${N}"
      hr
      echo -e "${Y}No se pudo descargar el binario${N}"
      echo -e "${R}Instalacion cancelada${N}"
      pause
      return
    fi
    hr
  fi

  local pub=""
  [[ -e "${VPS_slow}/server.pub" ]] && pub="$(cat "${VPS_slow}/server.pub")"

  if [[ -n "$pub" ]]; then
    echo -ne "${W}Usar clave existente [S/N]: ${G}"
    read -r ex_key
    tput cuu1 && tput dl1

    case "$ex_key" in
      s|S|y|Y) echo -e "${Y}Tu clave: ${G}$pub${N}" ;;
      n|N) rm -rf "${VPS_slow}/server.key" "${VPS_slow}/server.pub"
           "${VPS_inst}/dns-server" -gen-key -privkey-file "${VPS_slow}/server.key" -pubkey-file "${VPS_slow}/server.pub" &>/dev/null
           echo -e "${Y}Tu clave: ${G}$(cat "${VPS_slow}/server.pub")${N}" ;;
      *) ;;
    esac
  else
    rm -rf "${VPS_slow}/server.key" "${VPS_slow}/server.pub"
    "${VPS_inst}/dns-server" -gen-key -privkey-file "${VPS_slow}/server.key" -pubkey-file "${VPS_slow}/server.pub" &>/dev/null
    echo -e "${Y}Tu clave: ${G}$(cat "${VPS_slow}/server.pub")${N}"
  fi
  hr
  echo -ne "${W}Iniciando SlowDNS....${N}"

  iptables -I INPUT -p udp --dport 5300 -j ACCEPT >/dev/null 2>&1
  iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300 >/dev/null 2>&1

  if screen -dmS slowdns "${VPS_inst}/dns-server" -udp :5300 -privkey-file "${VPS_slow}/server.key" "$NS" 127.0.0.1:"$PORT"; then
    echo -e "${G}Con exito!!!${N}"
  else
    echo -e "${R}Con fallo!!!${N}"
  fi
  pause
}

reset_slow(){
  clear
  hr
  echo -ne "${W}Reiniciando SlowDNS....${N}"
  screen -ls | grep slowdns | cut -d. -f1 | awk '{print $1}' | xargs kill >/dev/null 2>&1
  NS="$(cat "${VPS_slow}/domain_ns")"
  PORT="$(cat "${VPS_slow}/puerto")"
  if screen -dmS slowdns "${VPS_inst}/dns-server" -udp :5300 -privkey-file "${VPS_slow}/server.key" "$NS" 127.0.0.1:"$PORT"; then
    echo -e "${G}Con exito!!!${N}"
  else
    echo -e "${R}Con fallo!!!${N}"
  fi
  pause
}

stop_slow(){
  clear
  hr
  echo -ne "${W}Deteniendo SlowDNS....${N}"
  if screen -ls | grep slowdns | cut -d. -f1 | awk '{print $1}' | xargs kill >/dev/null 2>&1; then
    echo -e "${G}Con exito!!!${N}"
  else
    echo -e "${R}Con fallo!!!${N}"
  fi
  pause
}

main_menu(){
  require_root

  while true; do
    clear
    hr
    echo -e "${W}          INSTALADOR SLOWDNS By SinNombre${N}"
    hr
    echo -e "${R}[${Y}1${R}]${N} ${C}Ver Informacion${N}"
    echo -e "${R}[${Y}2${R}]${N} ${G}Iniciar SlowDNS${N}"
    echo -e "${R}[${Y}3${R}]${N} ${Y}Reiniciar SlowDNS${N}"
    echo -e "${R}[${Y}4${R}]${N} ${R}Parar SlowDNS${N}"
    hr
    echo -e "${R}[${Y}0${R}]${N} ${W}VOLVER${N}"
    hr
    echo ""
    echo -ne "${W}Selecciona una opcion: ${G}"
    read -r opcion

    case "${opcion:-}" in
      1) info ;;
      2) ini_slow ;;
      3) reset_slow ;;
      4) stop_slow ;;
      0) break ;;
      *) echo -e "${B}Opcion invalida${N}"; sleep 1 ;;
    esac
  done
}

main_menu
