#!/bin/bash
set -euo pipefail

# =========================================================
# SinNombre v1.0 - INSTALADORES (Protocolos) - MENÚ VISUAL (lista una sola, con espacios)
# Adaptación visual por Copilot, 2026-03-05
# =========================================================

R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
B='\033[0;34m'
C='\033[0;36m'
W='\033[1;37m'
N='\033[0m'
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
    echo -e "${R}Estado:${N} ${Y}En desarrollo...${N}"
    pause
  fi
}

is_active_systemd() { systemctl is-active --quiet "$1" 2>/dev/null; }
status_badge() { [[ "${1:-false}" == "true" ]] && echo -e "${G}[ ON ]${N}" || echo -e "${R}[OFF]${N}"; }

check_ssh_status()        { ( is_active_systemd ssh || is_active_systemd sshd ) && echo "true" || echo "false"; }
check_dropbear_status()   { ( is_active_systemd dropbear || pgrep -x dropbear >/dev/null 2>&1 ) && echo "true" || echo "false"; }
check_stunnel_status()    { ( is_active_systemd stunnel4 || pgrep -x stunnel4 >/dev/null 2>&1 ) && echo "true" || echo "false"; }
check_squid_status()      { ( is_active_systemd squid || is_active_systemd squid3 ) && echo "true" || echo "false"; }
check_haproxy_mux_status(){ ( is_active_systemd haproxy-mux || is_active_systemd haproxy ) && echo "true" || echo "false"; }
check_slowdns_status() {
  if is_active_systemd dnstt.service || is_active_systemd dnstt-client.service || is_active_systemd dnstt-server.service \
     || is_active_systemd sn-dnstt-client.service || is_active_systemd sn-dnstt-server.service; then
    echo "true"; return 0
  fi
  if pgrep -f 'dnstt|slowdns|dnstt-client|dnstt-server' >/dev/null 2>&1; then
    echo "true"; return 0
  fi
  echo "false"
}

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

check_socks_status()     { py_socks_is_on && echo "true" || echo "false"; }
check_v2ray_status()     { ( is_active_systemd v2ray || is_active_systemd xray ) && echo "true" || echo "false"; }
check_udp_custom_status(){ pgrep -f 'udp-custom|udpcustom|udp_custom' >/dev/null 2>&1 && echo "true" || echo "false"; }
check_badvpn_status()    { pgrep -x badvpn-udpgw >/dev/null 2>&1 && echo "true" || echo "false"; }

BOX_LINE="══════════════════════════ / / / ══════════════════════════"
hr() { echo -e "${R}${BOX_LINE}${N}"; }
sep() { echo -e "${R}──────────────────────────────────────────────────────────${N}"; }

main_menu_single() {
  while true; do
    clear

    local ssh_st dropbear_st stunnel_st squid_st socks_st v2_st udp_st badvpn_st haproxy_st slowdns_st

    ssh_st="$(status_badge "$(check_ssh_status)")"
    dropbear_st="$(status_badge "$(check_dropbear_status)")"
    stunnel_st="$(status_badge "$(check_stunnel_status)")"
    socks_st="$(status_badge "$(check_socks_status)")"
    squid_st="$(status_badge "$(check_squid_status)")"
    badvpn_st="$(status_badge "$(check_badvpn_status)")"
    udp_st="$(status_badge "$(check_udp_custom_status)")"
    v2_st="$(status_badge "$(check_v2ray_status)")"
    haproxy_st="$(status_badge "$(check_haproxy_mux_status)")"
    slowdns_st="$(status_badge "$(check_slowdns_status)")"

    hr
    echo -e "${W}               INSTALADORES & PROTOCOLOS${N}"
    hr

    # Lista única, con un espacio entre cada protocolo
    printf "${R}[${Y}1${R}]${N}  ${C}AJUSTES SSH${N}        %s\n"      "$ssh_st"
    printf "${R}[${Y}2${R}]${N}  ${C}DROPBEAR${N}           %s\n"      "$dropbear_st"
    printf "${R}[${Y}3${R}]${N}  ${C}STUNNEL (SSL)${N}      %s\n"      "$stunnel_st"
    printf "${R}[${Y}4${R}]${N}  ${C}SOCKS (PYTHON)${N}     %s\n"      "$socks_st"
    printf "${R}[${Y}5${R}]${N}  ${C}SQUID PROXY${N}        %s\n"      "$squid_st"
    printf "${R}[${Y}6${R}]${N}  ${C}BADVPN-UDPGW${N}       %s\n"      "$badvpn_st"
    printf "${R}[${Y}7${R}]${N}  ${C}UDP-CUSTOM${N}         %s\n"      "$udp_st"
    printf "${R}[${Y}8${R}]${N}  ${C}V2RAY${N}              %s\n"      "$v2_st"
    printf "${R}[${Y}9${R}]${N}  ${C}HAPROXY MUX${N}        %s\n"      "$haproxy_st"
    printf "${R}[${Y}10${R}]${N} ${C}SLOWDNS${N}            %s\n"      "$slowdns_st"
    sep
    printf "${R}[${Y}0${R}]${N}  ${C}VOLVER${N}\n"
    hr

    echo ""
    echo -ne "${W}┌─[${G}${BOLD}Seleccione una opción${W}]${N}\n"
    echo -ne "╰─> : ${G}"
    read -r op
    echo -ne "${N}"

    case "${op:-}" in
      1|01) run_proto "Protocolos/ssh.sh" ;;
      2|02) run_proto "Protocolos/dropbear.sh" ;;
      3|03) run_proto "Protocolos/stunnel.sh" ;;
      4|04) run_proto "Protocolos/socks.sh" ;;
      5|05) run_proto "Protocolos/squid.sh" ;;
      6|06) run_proto "Protocolos/badvpn.sh" ;;
      7|07) run_proto "Protocolos/udp-custom.sh" ;;
      8|08) run_proto "Protocolos/v2ray.sh" ;;
      9|09) run_proto "Protocolos/haproxy_mux.sh" ;;
      10)   run_proto "Protocolos/slowdns.sh" ;;
      0|00) break ;;
      *) echo -e "${B}Opción inválida${N}"; sleep 1 ;;
    esac
  done
}

main_menu_single
