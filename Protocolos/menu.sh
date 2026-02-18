#!/bin/bash
set -euo pipefail

# =========================================================
# SinNombre v1.0 - INSTALADORES (Protocolos) - MENÚ ÚNICO
# Creador: @SIN_NOMBRE22
# Archivo: SN/Protocolos/menu.sh
# =========================================================

R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
B='\033[0;34m'
C='\033[0;36m'
W='\033[1;37m'
N='\033[0m'
D='\033[2m'
BOLD='\033[1m'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

pause() { echo ""; read -r -p "Presiona Enter para continuar..."; }
back_to_main() { [[ -f "${ROOT_DIR}/menu" ]] && bash "${ROOT_DIR}/menu" || exit 0; }

run_proto() {
  local rel="${1-}"
  local path="${ROOT_DIR}/${rel}"
  if [[ -n "${rel}" && -f "$path" ]]; then
    bash "$path"
  else
    echo ""
    echo -e "${Y}${BOLD}Módulo no disponible:${N} ${C}${rel:-"(sin ruta)"}${N}"
    echo -e "${D}Estado:${N} ${Y}En desarrollo...${N}"
    pause
  fi
}

is_active_systemd() { systemctl is-active --quiet "$1" 2>/dev/null; }
status_badge() { [[ "${1:-false}" == "true" ]] && echo -e "${G}[ ON ]${N}" || echo -e "${R}[OFF]${N}"; }

check_ssh_status() { ( is_active_systemd ssh || is_active_systemd sshd ) && echo "true" || echo "false"; }
check_dropbear_status() { ( is_active_systemd dropbear || pgrep -x dropbear >/dev/null 2>&1 ) && echo "true" || echo "false"; }
check_stunnel_status() { ( is_active_systemd stunnel4 || pgrep -x stunnel4 >/dev/null 2>&1 ) && echo "true" || echo "false"; }
check_squid_status() { ( is_active_systemd squid || is_active_systemd squid3 ) && echo "true" || echo "false"; }
check_haproxy_mux_status() { ( is_active_systemd haproxy-mux || is_active_systemd haproxy ) && echo "true" || echo "false"; }

py_socks_units() {
  systemctl list-units --type=service --all 2>/dev/null \
    | awk '{print $1}' \
    | grep -E '^python\.[0-9]+\.service$' || true
}

py_socks_is_on() {
  local u=""
  while read -r u; do
    [[ -z "${u:-}" ]] && continue
    systemctl is-active --quiet "$u" && return 0
  done < <(py_socks_units)
  return 1
}

check_socks_status() { py_socks_is_on && echo "true" || echo "false"; }
check_v2ray_status() { ( is_active_systemd v2ray || is_active_systemd xray ) && echo "true" || echo "false"; }
check_udp_custom_status() { pgrep -f 'udp-custom|udpcustom|udp_custom' >/dev/null 2>&1 && echo "true" || echo "false"; }
check_badvpn_status() { pgrep -x badvpn-udpgw >/dev/null 2>&1 && echo "true" || echo "false"; }

# =========================================================
# UI FIJA AL CUADRO (58 chars visibles)
# =========================================================
BOX_W=58
BOX_LINE="══════════════════════════ / / / ══════════════════════════"

hr() { echo -e "${R}${BOX_LINE}${N}"; }

print_item_list() {
  local n="${1}" name="${2}" st="${3}"
  printf "${W}> ${Y}%2s${W} ─ ${C}${BOLD}%-15s${N} %s\n" "$n" "$name" "$st"
}

title_box() {
  local t="${1-}"
  hr
  echo -e "                 ${W}${BOLD} ░▒▓  ${t}  ▓▒░${N}"
  hr
}

main_menu_single() {
  while true; do
    clear

    local ssh_st dropbear_st stunnel_st squid_st socks_st v2_st udp_st badvpn_st haproxy_st

    ssh_st="$(status_badge "$(check_ssh_status)")"
    dropbear_st="$(status_badge "$(check_dropbear_status)")"
    stunnel_st="$(status_badge "$(check_stunnel_status)")"
    squid_st="$(status_badge "$(check_squid_status)")"
    socks_st="$(status_badge "$(check_socks_status)")"
    v2_st="$(status_badge "$(check_v2ray_status)")"
    udp_st="$(status_badge "$(check_udp_custom_status)")"
    badvpn_st="$(status_badge "$(check_badvpn_status)")"
    haproxy_st="$(status_badge "$(check_haproxy_mux_status)")"
 #   websoket_st="$(status_badge "$(check_websoket_status)")"
    title_box "INSTALADORES"
    echo ""

    print_item_list "01" "AJUSTES SSH" "$ssh_st"
    print_item_list "02" "DROPBEAR" "$dropbear_st"
    print_item_list "03" "STUNNEL (SSL)" "$stunnel_st"
    print_item_list "04" "SOCKS (PYTHON)" "$socks_st"
    print_item_list "05" "SQUID PROXY" "$squid_st"
    print_item_list "06" "BADVPN-UDPGW" "$badvpn_st"
    print_item_list "07" "UDP-CUSTOM" "$udp_st"
    print_item_list "08" "V2RAY" "$v2_st"
    print_item_list "09" "HAPROXY MUX" "$haproxy_st"
#    print_item_list "10" "WEBSOKET" "$websoket_st"

    echo ""
    printf "${W}> ${Y}%2s${W} ─ ${C}${BOLD}%-15s${N}\n" "00" "VOLVER"

    hr
    echo ""
    echo -ne "${W}┌─[${G}${BOLD}Seleccione una opción${W}]${N}\n"
    echo -ne "╰─> : ${G}"
    read -r op

    case "${op:-}" in
      01|1) run_proto "Protocolos/ssh.sh" ;;
      02|2) run_proto "Protocolos/dropbear.sh" ;;
      03|3) run_proto "Protocolos/stunnel.sh" ;;
      04|4) run_proto "Protocolos/socks.sh" ;;
      05|5) run_proto "Protocolos/squid.sh" ;;
      06|6) run_proto "Protocolos/badvpn.sh" ;;
      07|7) run_proto "Protocolos/udp-custom.sh" ;;
      08|8) run_proto "Protocolos/v2ray.sh" ;;
      09|9) run_proto "Protocolos/haproxy_mux.sh" ;;
  #    10|10 run_proto "Protocolos/websoket/websoket.sh"
      00|0) break ;;
      *) echo -e "${B}Opción inválida${N}"; sleep 1 ;;
    esac
  done
}

main_menu_single
