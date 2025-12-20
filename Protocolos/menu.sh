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

# ------------------------------
# SOCKS (PYTHON) real status
# ------------------------------
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

py_socks_ports() {
  ls /etc/systemd/system/python.*.service 2>/dev/null \
    | sed -n 's/.*python\.\([0-9]\+\)\.service/\1/p' \
    | sort -n \
    | tr '\n' ' ' | sed 's/[[:space:]]\+$//' || true
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

# =========================================================
# UI FIJA AL CUADRO (58 chars visibles)
# =========================================================
BOX_W=58
BOX_LINE="══════════════════════════ / / / ══════════════════════════"

trim_to() {
  local s="${1-}" max="${2-0}"
  if (( ${#s} <= max )); then
    printf "%s" "$s"
  else
    local cut=$((max - 1))
    (( cut < 1 )) && cut=1
    printf "%s…" "${s:0:cut}"
  fi
}

center_text() {
  local t="${1-}"
  local len=${#t}
  if (( len >= BOX_W )); then
    trim_to "$t" "$BOX_W"
    return 0
  fi
  local left=$(( (BOX_W - len) / 2 ))
  local right=$(( BOX_W - len - left ))
  printf "%*s%s%*s" "$left" "" "$t" "$right" ""
}

hr() { echo -e "${R}${BOX_LINE}${N}"; }

title_box() {
  local t="${1-}"
  hr
  echo -e "${W}${BOLD}$(center_text "$t")${N}"
  hr
}

plain_item() { local num="${1-}" name="${2-}" badge="${3-}"; printf "[%s]> %s %s" "$num" "$name" "$badge"; }

print_row_2col_fixed() {
  local n1="${1-}" name1="${2-}" st1="${3-}"
  local n2="${4-}" name2="${5-}" st2="${6-}"

  local gap="  "
  local col_w=$(( (BOX_W - ${#gap}) / 2 ))

  local overhead=12
  local max_name=$((col_w - overhead))
  (( max_name < 6 )) && max_name=6

  local name1_fit name2_fit
  name1_fit="$(trim_to "$name1" "$max_name")"
  name2_fit="$(trim_to "$name2" "$max_name")"

  local left_col right_col
  left_col="$(printf "%b" "${R}[${Y}${n1}${R}]${N}${W}> ${C}${BOLD}${name1_fit}${N} ${st1}")"

  if [[ -n "${n2:-}" ]]; then
    right_col="$(printf "%b" "${R}[${Y}${n2}${R}]${N}${W}> ${C}${BOLD}${name2_fit}${N} ${st2}")"
    local left_fit_plain
    left_fit_plain="$(plain_item "$n1" "$name1_fit" "$(echo "$st1" | grep -q ON && echo "[ON ]" || echo "[OFF]")")"
    local pad=$(( col_w - ${#left_fit_plain} ))
    (( pad < 1 )) && pad=1
    printf "%b%*s%s%b\n" "$left_col" "$pad" "" "$gap" "$right_col"
  else
    printf "%b\n" "$left_col"
  fi
}

# NUEVO: separador profesional dentro del cuadro (58 chars)
  section_divider() {
  local title="${1-}"
  title="$(echo "$title" | tr '[:lower:]' '[:upper:]')"
  local inner_w=$(( BOX_W - 2 ))   # sin bordes
  local text=" ${title} "
  # recorta si es muy largo
  if (( ${#text} > inner_w )); then
    text="$(trim_to "$text" "$inner_w")"
  fi
  local fill=$(( inner_w - ${#text} ))
  local left=$(( fill / 2 ))
  local right=$(( fill - left ))

  local L=""; local Rr=""
  [[ $left -gt 0 ]] && L="$(printf '%*s' "$left" '' | tr ' ' '=')"
  [[ $right -gt 0 ]] && Rr="$(printf '%*s' "$right" '' | tr ' ' '=')"

  echo -e "${R}+${L}${W}${BOLD}${text}${N}${R}${Rr}+${N}"
}


main_menu_single() {
  while true; do
    clear

    local ssh_st dropbear_st stunnel_st squid_st socks_st ws_st slowdns_st v2_st
    local udp_st hyst_st badvpn_st
    local ovpn_st wg_st fb_st cu_st at_st sshgo_st

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

    title_box "INSTALADORES"
 #   echo -e "${D}$(trim_to "Todo en una pantalla: Túneles + UDP + Extras" "$BOX_W")${N}"

    local pyports
#    pyports="$(py_socks_ports)"
#   [[ -n "${pyports:-}" ]] && echo -e "${D}$(trim_to "Socks Python ports: ${pyports}" "$BOX_W")${N}"

    echo ""

    section_divider "Túneles"
    print_row_2col_fixed "1"  "AJUSTES SSH"   "$ssh_st"      "5"  "SOCKS (PYTHON)" "$socks_st"
    print_row_2col_fixed "2"  "DROPBEAR"      "$dropbear_st" "6"  "WS-EPRO / WS"   "$ws_st"
    print_row_2col_fixed "3"  "STUNNEL (SSL)" "$stunnel_st"  "7"  "SLOWDNS"        "$slowdns_st"
    print_row_2col_fixed "4"  "SQUID"         "$squid_st"    "8"  "V2RAY / XRAY"   "$v2_st"
    echo ""

    section_divider "UDP"
    print_row_2col_fixed "9"  "UDP-CUSTOM"    "$udp_st"      "10" "UDP-HYSTERIA"   "$hyst_st"
    print_row_2col_fixed "11" "BADVPN-UDPGW"  "$badvpn_st"
    echo ""

    section_divider "Extras"
    print_row_2col_fixed "12" "OPENVPN"       "$ovpn_st"     "15" "CHECKUSER"      "$cu_st"
    print_row_2col_fixed "13" "WIREGUARD"     "$wg_st"       "16" "ATKEN / HASH"   "$at_st"
    print_row_2col_fixed "14" "FILEBROWSER"   "$fb_st"       "17" "SSHGO"          "$sshgo_st"

    echo ""
    hr
    echo -e "${R}[${Y}0${R}]${N}  ${W}${BOLD}VOLVER AL MENÚ PRINCIPAL${N}"
    hr
    echo ""
    echo -ne "${W}Selecciona una opción: ${G}"
    read -r op

    case "${op:-}" in
      1)  run_proto "Protocolos/ssh.sh" ;;
      2)  run_proto "Protocolos/dropbear.sh" ;;
      3)  run_proto "Protocolos/stunnel.sh" ;;
      4)  run_proto "Protocolos/squid.sh" ;;
      5)  run_proto "Protocolos/socks.sh" ;;
      6)  run_proto "Protocolos/ws-epro.sh" ;;
      7)  run_proto "Protocolos/slowdns.sh" ;;
      8)  run_proto "Protocolos/v2ray.sh" ;;
      9)  run_proto "Protocolos/udp-custom.sh" ;;
      10) run_proto "Protocolos/udp-hysteria.sh" ;;
      11) run_proto "Protocolos/badvpn.sh" ;;
      12) run_proto "Protocolos/openvpn.sh" ;;
      13) run_proto "Protocolos/wireguard.sh" ;;
      14) run_proto "Protocolos/filebrowser.sh" ;;
      15) run_proto "Protocolos/checkuser.sh" ;;
      16) run_proto "Protocolos/atken.sh" ;;
      17) run_proto "Protocolos/sshgo.sh" ;;
#            0)  return 0 ;;  # Si es una función, return vuelve al llamador
      # O también:
      0)  break ;;     # Rompe el bucle 'while' y permite que el script siga

      *)  echo -e "${B}Opción inválida${N}"; sleep 1 ;;
    esac
  done
}

main_menu_single
