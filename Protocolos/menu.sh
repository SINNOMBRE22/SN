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
status_badge() { [[ "${1:-false}" == "true" ]] && echo -e "${G}[ON ]${N}" || echo -e "${R}[OFF]${N}"; }

check_ssh_status() { ( is_active_systemd ssh || is_active_systemd sshd ) && echo "true" || echo "false"; }
check_dropbear_status() { ( is_active_systemd dropbear || pgrep -x dropbear >/dev/null 2>&1 ) && echo "true" || echo "false"; }
check_stunnel_status() { ( is_active_systemd stunnel4 || pgrep -x stunnel4 >/dev/null 2>&1 ) && echo "true" || echo "false"; }
check_squid_status() { ( is_active_systemd squid || is_active_systemd squid3 ) && echo "true" || echo "false"; }

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
check_ws_status() { pgrep -f 'ws-epro|websocket|ws-tunnel|wstunnel' >/dev/null 2>&1 && echo "true" || echo "false"; }
check_slowdns_status() { pgrep -f 'slowdns|dns-server|dnstt' >/dev/null 2>&1 && echo "true" || echo "false"; }
check_v2ray_status() { ( is_active_systemd v2ray || is_active_systemd xray ) && echo "true" || echo "false"; }
check_udp_custom_status() { pgrep -f 'udp-custom|udpcustom|udp_custom' >/dev/null 2>&1 && echo "true" || echo "false"; }
check_hysteria_status() { ( is_active_systemd hysteria || pgrep -f 'hysteria' >/dev/null 2>&1 ) && echo "true" || echo "false"; }
check_badvpn_status() { pgrep -x badvpn-udpgw >/dev/null 2>&1 && echo "true" || echo "false"; }
check_openvpn_status() {
  ( is_active_systemd openvpn || systemctl list-units --type=service 2>/dev/null | grep -q 'openvpn@' ) && echo "true" || echo "false"
}
check_wireguard_status() { ( ip link show wg0 >/dev/null 2>&1 || is_active_systemd wg-quick@wg0 ) && echo "true" || echo "false"; }
check_filebrowser_status() { ( is_active_systemd filebrowser || pgrep -f 'filebrowser' >/dev/null 2>&1 ) && echo "true" || echo "false"; }
check_checkuser_status() { ( is_active_systemd checkuser || pgrep -f 'checkuser' >/dev/null 2>&1 ) && echo "true" || echo "false"; }
check_atken_status() { pgrep -f 'atken|aToken|hash' >/dev/null 2>&1 && echo "true" || echo "false"; }
check_sshgo_status() { pgrep -x sshgo >/dev/null 2>&1 && echo "true" || echo "false"; }
check_psiphon_status() { screen -list | grep -q psiserver && echo "true" || echo "false"; }

# =========================================================
# UI FIJA AL CUADRO (58 chars visibles)
# =========================================================
BOX_W=58
BOX_LINE="══════════════════════════ / / / ══════════════════════════"

hr() { echo -e "${R}${BOX_LINE}${N}"; }

print_item_list() {
  local n="${1}" name="${2}" st="${3}"
  printf "${R}[${Y}${n}${R}]${N}${W}> ${C}${BOLD}${name}${N} ${st}\n"
}

title_box() {
  local t="${1-}"
  hr
  echo -e "${W}${BOLD}$(printf '%*s' $(( (BOX_W - ${#t}) / 2 )) '')${t}${N}"
  hr
}

main_menu_single() {
  while true; do
    clear

    local ssh_st dropbear_st stunnel_st squid_st socks_st ws_st slowdns_st v2_st
    local udp_st hyst_st badvpn_st ovpn_st wg_st fb_st cu_st at_st sshgo_st psiphon_st

    ssh_st="$(status_badge "$(check_ssh_status)")"
    dropbear_st="$(status_badge "$(check_dropbear_status)")"
    stunnel_st="$(status_badge "$(check_stunnel_status)")"
    squid_st="$(status_badge "$(check_squid_status)")"
    socks_st="$(status_badge "$(check_socks_status)")"
    ws_st="$(status_badge "$(check_ws_status)")"
    slowdns_st="$(status_badge "$(check_slowdns_status)")"
    v2_st="$(status_badge "$(check_v2ray_status)")"
    udp_st="$(status_badge "$(check_udp_custom_status)")"
    hyst_st="$(status_badge "$(check_hysteria_status)")"
    badvpn_st="$(status_badge "$(check_badvpn_status)")"
    ovpn_st="$(status_badge "$(check_openvpn_status)")"
    wg_st="$(status_badge "$(check_wireguard_status)")"
    fb_st="$(status_badge "$(check_filebrowser_status)")"
    cu_st="$(status_badge "$(check_checkuser_status)")"
    at_st="$(status_badge "$(check_atken_status)")"
    sshgo_st="$(status_badge "$(check_sshgo_status)")"
    psiphon_st="$(status_badge "$(check_psiphon_status)")"

    title_box "INSTALADORES"
    echo ""

    echo -e "${W}─────────────── CORE DE ACCESO ───────────────${N}"
    print_item_list "1"  "AJUSTES SSH"   "$ssh_st"
    print_item_list "2"  "DROPBEAR"      "$dropbear_st"
    print_item_list "3"  "SSHGO"         "$sshgo_st"

    echo ""
    echo -e "${W}──────────── TÚNELES & CAMUFLAJE ─────────────${N}"
    print_item_list "4"  "STUNNEL (SSL)" "$stunnel_st"
    print_item_list "5"  "WS-EPRO / WS"   "$ws_st"
    print_item_list "6"  "SQUID PROXY"         "$squid_st"
    print_item_list "7"  "SLOWDNS"        "$slowdns_st"
    print_item_list "8"  "SOCKS (PYTHON)" "$socks_st"

    echo ""
    echo -e "${W}────────────── ACELERACIÓN UDP ──────────────${N}"
    print_item_list "9"  "BADVPN-UDPGW"  "$badvpn_st"
    print_item_list "10" "UDP-CUSTOM"    "$udp_st"
    print_item_list "11" "UDP-HYSTERIA"   "$hyst_st"

    echo ""
    echo -e "${W}──────────── MOTORES MODERNOS ──────────────${N}"
    print_item_list "12" "V2RAY / XRAY"   "$v2_st"
    print_item_list "13" "PSIPHON"       "$psiphon_st"

    echo ""
    echo -e "${W}────────────── VPN CLÁSICAS ────────────────${N}"
    print_item_list "14" "OPENVPN"       "$ovpn_st"
    print_item_list "15" "WIREGUARD"     "$wg_st"

    echo ""
    echo -e "${W}─────────── ADMIN & UTILIDADES ─────────────${N}"
    print_item_list "16" "CHECKUSER"     "$cu_st"
    print_item_list "17" "ATKEN / HASH"  "$at_st"
    print_item_list "18" "FILEBROWSER"   "$fb_st"

    echo ""
    hr
    echo -e "${R}[${Y}0${R}]${N}  ${W}${BOLD}VOLVER AL MENÚ PRINCIPAL${N}"
    hr
    echo ""
    echo -ne "${W}┌─[${G}${BOLD}Seleccione una opción${W}]${N}\n"
    echo -ne "╰─> : ${G}"
    read -r op

    case "${op:-}" in
      1)  run_proto "Protocolos/ssh.sh" ;;
      2)  run_proto "Protocolos/dropbear.sh" ;;
      3)  run_proto "Protocolos/sshgo.sh" ;;
      4)  run_proto "Protocolos/stunnel.sh" ;;
      5)  run_proto "Protocolos/ws-epro.sh" ;;
      6)  run_proto "Protocolos/squid.sh" ;;
      7)  run_proto "Protocolos/slowdns.sh" ;;
      8)  run_proto "Protocolos/socks.sh" ;;
      9)  run_proto "Protocolos/badvpn.sh" ;;
      10) run_proto "Protocolos/udp-custom.sh" ;;
      11) run_proto "Protocolos/udp-hysteria.sh" ;;
      12) run_proto "Protocolos/v2ray.sh" ;;
      13) run_proto "Protocolos/psiphon.sh" ;;
      14) run_proto "Protocolos/openvpn.sh" ;;
      15) run_proto "Protocolos/wireguard.sh" ;;
      16) run_proto "Protocolos/checkuser.sh" ;;
      17) run_proto "Protocolos/atken.sh" ;;
      18) run_proto "Protocolos/filebrowser.sh" ;;
      0)  break ;;
      *)  echo -e "${B}Opción inválida${N}"; sleep 1 ;;
    esac
  done
}

main_menu_single
