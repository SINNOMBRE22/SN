#!/bin/bash
set -euo pipefail

# =========================================================
# SinNombre v1.0 - INSTALADORES (Protocolos)
# Creador: @SIN_NOMBRE22
# Archivo: SN/Protocolos/menu.sh
#
# FIX 2025-12-14:
# - SOCKS (PYTHON) ahora se detecta por systemd REAL:
#   ON si existe algún servicio python.<puerto>.service activo.
# - Ya no se confunde con Dropbear ni con "ps|grep".
# - (Opcional) muestra puertos python detectados por units.
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
  local rel="$1"
  local path="${ROOT_DIR}/${rel}"
  if [[ -f "$path" ]]; then
    bash "$path"
  else
    echo ""
    echo -e "${Y}${BOLD}Módulo no disponible:${N} ${C}${rel}${N}"
    echo -e "${D}Estado:${N} ${Y}En desarrollo...${N}"
    pause
  fi
}

is_active_systemd() { systemctl is-active --quiet "$1" 2>/dev/null; }

status_badge() {
  local ok="$1"
  if [[ "$ok" == "true" ]]; then echo -e "${G}[ON ]${N}"; else echo -e "${R}[OFF]${N}"; fi
}

check_ssh_status() { if is_active_systemd ssh || is_active_systemd sshd; then echo "true"; else echo "false"; fi; }
check_dropbear_status() { if is_active_systemd dropbear || pgrep -x dropbear >/dev/null 2>&1; then echo "true"; else echo "false"; fi; }
check_stunnel_status() { if is_active_systemd stunnel4 || pgrep -x stunnel4 >/dev/null 2>&1; then echo "true"; else echo "false"; fi; }
check_squid_status() { if is_active_systemd squid || is_active_systemd squid3; then echo "true"; else echo "false"; fi; }

# ------------------------------
# FIX: SOCKS (PYTHON) real status
# ------------------------------
py_socks_units() {
  # lista units python.<n>.service desde systemd
  systemctl list-units --type=service --all 2>/dev/null \
    | awk '{print $1}' \
    | grep -E '^python\.[0-9]+\.service$' || true
}

py_socks_is_on() {
  local u
  while read -r u; do
    [[ -z "${u:-}" ]] && continue
    systemctl is-active --quiet "$u" && return 0
  done < <(py_socks_units)
  return 1
}

py_socks_ports() {
  # puertos por archivos unit (para mostrar en UI si quieres)
  ls /etc/systemd/system/python.*.service 2>/dev/null \
    | sed -n 's/.*python\.\([0-9]\+\)\.service/\1/p' \
    | sort -n \
    | tr '\n' ' ' | sed 's/[[:space:]]\+$//' || true
}

check_socks_status() {
  if py_socks_is_on; then echo "true"; else echo "false"; fi
}

check_ws_status() { if pgrep -f 'ws-epro|websocket|ws-tunnel|wstunnel' >/dev/null 2>&1; then echo "true"; else echo "false"; fi; }
check_slowdns_status() { if pgrep -f 'slowdns|dns-server|dnstt' >/dev/null 2>&1; then echo "true"; else echo "false"; fi; }
check_v2ray_status() { if is_active_systemd v2ray || is_active_systemd xray; then echo "true"; else echo "false"; fi; }

check_udp_custom_status() { if pgrep -f 'udp-custom|udpcustom|udp_custom' >/dev/null 2>&1; then echo "true"; else echo "false"; fi; }
check_hysteria_status() { if is_active_systemd hysteria || pgrep -f 'hysteria' >/dev/null 2>&1; then echo "true"; else echo "false"; fi; }
check_badvpn_status() { if pgrep -x badvpn-udpgw >/dev/null 2>&1; then echo "true"; else echo "false"; fi; }

check_openvpn_status() {
  if is_active_systemd openvpn || systemctl list-units --type=service 2>/dev/null | grep -q 'openvpn@'; then echo "true"; else echo "false"; fi
}
check_wireguard_status() { if ip link show wg0 >/dev/null 2>&1 || is_active_systemd wg-quick@wg0; then echo "true"; else echo "false"; fi; }
check_filebrowser_status() { if is_active_systemd filebrowser || pgrep -f 'filebrowser' >/dev/null 2>&1; then echo "true"; else echo "false"; fi; }
check_checkuser_status() { if is_active_systemd checkuser || pgrep -f 'checkuser' >/dev/null 2>&1; then echo "true"; else echo "false"; fi; }
check_atken_status() { if pgrep -f 'atken|aToken|hash' >/dev/null 2>&1; then echo "true"; else echo "false"; fi; }
check_sshgo_status() { if pgrep -x sshgo >/dev/null 2>&1; then echo "true"; else echo "false"; fi; }

# =========================================================
# UI FIJA AL CUADRO (58 chars visibles)
# =========================================================
BOX_W=58
BOX_LINE="══════════════════════════ / / / ══════════════════════════"

trim_to() {
  local s="$1" max="$2"
  if (( ${#s} <= max )); then
    printf "%s" "$s"
  else
    local cut=$((max - 1))
    printf "%s…" "${s:0:cut}"
  fi
}

center_text() {
  local t="$1"
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
  local t="$1"
  hr
  echo -e "${W}${BOLD}$(center_text "$t")${N}"
  hr
}

plain_item() {
  local num="$1" name="$2" badge="$3"
  printf "[%s]> %s %s" "$num" "$name" "$badge"
}

print_row_2col_fixed() {
  local n1="$1" name1="$2" st1="$3"
  local n2="${4:-}" name2="${5:-}" st2="${6:-}"

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

print_option_line() {
  local num="$1" title="$2" desc="$3"
  local t="${title} - ${desc}"
  t="$(trim_to "$t" $((BOX_W - 8)) )"
  echo -e "${R}[${Y}${num}${R}]${N} ${C}${BOLD}${t}${N}"
}

# =========================
# MENÚ: TÚNELES
# =========================
menu_tuneles() {
  while true; do
    clear
    local ssh_st dropbear_st stunnel_st squid_st socks_st ws_st slowdns_st v2_st
    ssh_st="$(status_badge "$(check_ssh_status)")"
    dropbear_st="$(status_badge "$(check_dropbear_status)")"
    stunnel_st="$(status_badge "$(check_stunnel_status)")"
    squid_st="$(status_badge "$(check_squid_status)")"
    socks_st="$(status_badge "$(check_socks_status)")"
    ws_st="$(status_badge "$(check_ws_status)")"
    slowdns_st="$(status_badge "$(check_slowdns_status)")"
    v2_st="$(status_badge "$(check_v2ray_status)")"

    title_box "INSTALADORES - TÚNELES"
    echo -e "${D}$(trim_to "Incluye: SSH/Dropbear/Stunnel/Squid + Socks/WS/SlowDNS + V2Ray/Xray" "$BOX_W")${N}"

    # Opcional: mostrar puertos python detectados (sin romper el diseño).
    # Si no quieres mostrarlo, comenta estas 3 líneas.
    local pyports
    pyports="$(py_socks_ports)"
    [[ -n "${pyports:-}" ]] && echo -e "${D}$(trim_to "Socks Python ports: ${pyports}" "$BOX_W")${N}"

    echo ""

    print_row_2col_fixed "1" "AJUSTES SSH"   "$ssh_st"      "5" "SOCKS (PYTHON)" "$socks_st"
    print_row_2col_fixed "2" "DROPBEAR"      "$dropbear_st" "6" "WS-EPRO / WS"   "$ws_st"
    print_row_2col_fixed "3" "STUNNEL (SSL)" "$stunnel_st"  "7" "SLOWDNS"        "$slowdns_st"
    print_row_2col_fixed "4" "SQUID"         "$squid_st"    "8" "V2RAY / XRAY"   "$v2_st"

    echo ""
    hr
    echo -e "${R}[${Y}0${R}]${N}  ${W}${BOLD}VOLVER${N}"
    hr
    echo ""
    echo -ne "${W}Selecciona una opción: ${G}"
    read -r op

    case "${op:-}" in
      1) run_proto "Protocolos/ssh.sh" ;;
      2) run_proto "Protocolos/dropbear.sh" ;;
      3) run_proto "Protocolos/stunnel.sh" ;;
      4) run_proto "Protocolos/squid.sh" ;;
      5) run_proto "Protocolos/socks.sh" ;;
      6) run_proto "Protocolos/ws-epro.sh" ;;
      7) run_proto "Protocolos/slowdns.sh" ;;
      8) run_proto "Protocolos/v2ray.sh" ;;
      0) return ;;
      *) echo -e "${B}Opción inválida${N}"; sleep 1 ;;
    esac
  done
}

# =========================
# MENÚ: UDP
# =========================
menu_udp() {
  while true; do
    clear
    local u1 u2 u3
    u1="$(status_badge "$(check_udp_custom_status)")"
    u2="$(status_badge "$(check_hysteria_status)")"
    u3="$(status_badge "$(check_badvpn_status)")"

    title_box "INSTALADORES - UDP"
    echo ""

    print_row_2col_fixed "1" "UDP-CUSTOM"   "$u1"
    print_row_2col_fixed "2" "UDP-HYSTERIA" "$u2"
    print_row_2col_fixed "3" "BADVPN-UDPGW" "$u3"

    echo ""
    hr
    echo -e "${R}[${Y}0${R}]${N}  ${W}${BOLD}VOLVER${N}"
    hr
    echo ""
    echo -ne "${W}Selecciona una opción: ${G}"
    read -r op

    case "${op:-}" in
      1) run_proto "Protocolos/udp-custom.sh" ;;
      2) run_proto "Protocolos/udp-hysteria.sh" ;;
      3) run_proto "Protocolos/badvpn.sh" ;;
      0) return ;;
      *) echo -e "${B}Opción inválida${N}"; sleep 1 ;;
    esac
  done
}

# =========================
# MENÚ: EXTRAS
# =========================
menu_extras() {
  while true; do
    clear
    local ovpn wg fb cu at sshgo
    ovpn="$(status_badge "$(check_openvpn_status)")"
    wg="$(status_badge "$(check_wireguard_status)")"
    fb="$(status_badge "$(check_filebrowser_status)")"
    cu="$(status_badge "$(check_checkuser_status)")"
    at="$(status_badge "$(check_atken_status)")"
    sshgo="$(status_badge "$(check_sshgo_status)")"

    title_box "INSTALADORES - EXTRAS"
    echo ""

    print_row_2col_fixed "1" "OPENVPN"     "$ovpn"  "4" "CHECKUSER"    "$cu"
    print_row_2col_fixed "2" "WIREGUARD"   "$wg"    "5" "ATKEN / HASH" "$at"
    print_row_2col_fixed "3" "FILEBROWSER" "$fb"    "6" "SSHGO"        "$sshgo"

    echo ""
    hr
    echo -e "${R}[${Y}0${R}]${N}  ${W}${BOLD}VOLVER${N}"
    hr
    echo ""
    echo -ne "${W}Selecciona una opción: ${G}"
    read -r op

    case "${op:-}" in
      1) run_proto "Protocolos/openvpn.sh" ;;
      2) run_proto "Protocolos/wireguard.sh" ;;
      3) run_proto "Protocolos/filebrowser.sh" ;;
      4) run_proto "Protocolos/checkuser.sh" ;;
      5) run_proto "Protocolos/atken.sh" ;;
      6) run_proto "Protocolos/sshgo.sh" ;;
      0) return ;;
      *) echo -e "${B}Opción inválida${N}"; sleep 1 ;;
    esac
  done
}

main_menu() {
  while true; do
    clear
    title_box "INSTALADORES"
    echo -e "${D}$(trim_to "Selecciona una categoría para instalar/gestionar módulos." "$BOX_W")${N}"
    echo ""

    print_option_line "1" "TÚNELES" "Básicos + Socks + WS + SlowDNS + V2Ray/Xray"
    print_option_line "2" "UDP"     "UDP-Custom + Hysteria + BadVPN"
    print_option_line "3" "EXTRAS"  "OpenVPN + WireGuard + Filebrowser + otros"

    echo ""
    hr
    echo -e "${R}[${Y}0${R}]${N}  ${W}${BOLD}VOLVER AL MENÚ PRINCIPAL${N}"
    hr
    echo ""
    echo -ne "${W}Selecciona una opción: ${G}"
    read -r op

    case "${op:-}" in
      1) menu_tuneles ;;
      2) menu_udp ;;
      3) menu_extras ;;
      0) back_to_main ;;
      *) echo -e "${B}Opción inválida${N}"; sleep 1 ;;
    esac
  done
}

main_menu
