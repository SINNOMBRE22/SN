#!/bin/bash
set -euo pipefail

# =========================================================
# SinNombre v1.0 - INSTALADORES (Protocolos)
# Adaptación visual: @SIN_NOMBRE22
# =========================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── Cargar colores desde lib ────────────────────────────
LIB_COLORES="$ROOT_DIR/lib/colores.sh"
if [[ -f "$LIB_COLORES" ]]; then
  source "$LIB_COLORES"
else
  # Fallback: colores básicos si no encuentra la librería
  R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'
  W='\033[1;37m'; N='\033[0m'; BOLD='\033[1m'
  hr()  { echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"; }
  sep() { echo -e "${R}──────────────────────────────────────────────────────────${N}"; }
  pause() { echo ""; read -r -p "Presiona Enter para continuar..."; }
  clear_screen() { clear; }
fi

# ── Funciones de Lógica ──────────────────────────────────

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
  pgrep -f 'dnstt|slowdns|dnstt-client|dnstt-server' >/dev/null 2>&1 && echo "true" || echo "false"
}

py_socks_units() {
  systemctl list-units --type=service --all 2>/dev/null | awk '{print $1}' | grep -E '^python\.[0-9]+\.service$' || true
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
check_ssl_status()       { if ls /etc/SN/cert/*.crt >/dev/null 2>&1; then echo "true"; else echo "false"; fi; }
check_autostart_status() { if grep -q "# --- SN AUTOSTART ---" ~/.bashrc 2>/dev/null; then echo "true"; else echo "false"; fi; }

# =========================================================
#  MENÚ PRINCIPAL
# =========================================================

main_menu_single() {
  while true; do
    clear

    # Captura de estados
    local ssh_st dropbear_st stunnel_st squid_st socks_st v2_st udp_st badvpn_st haproxy_st slowdns_st ssl_st autostart_st
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
    ssl_st="$(status_badge "$(check_ssl_status)")"
    autostart_st="$(status_badge "$(check_autostart_status)")"

    hr
    echo -e "${W}               INSTALADORES & PROTOCOLOS${N}"
    hr

    printf " ${R}[${Y}01${R}] ${R}» ${C}%-20s${N} %s\n" "AJUSTES SSH" "$ssh_st"
    printf " ${R}[${Y}02${R}] ${R}» ${C}%-20s${N} %s\n" "DROPBEAR" "$dropbear_st"
    printf " ${R}[${Y}03${R}] ${R}» ${C}%-20s${N} %s\n" "STUNNEL (SSL)" "$stunnel_st"
    printf " ${R}[${Y}04${R}] ${R}» ${C}%-20s${N} %s\n" "SOCKS (PYTHON)" "$socks_st"
    printf " ${R}[${Y}05${R}] ${R}» ${C}%-20s${N} %s\n" "SQUID PROXY" "$squid_st"
    printf " ${R}[${Y}06${R}] ${R}» ${C}%-20s${N} %s\n" "BADVPN-UDPGW" "$badvpn_st"
    printf " ${R}[${Y}07${R}] ${R}» ${C}%-20s${N} %s\n" "UDP-CUSTOM" "$udp_st"
    printf " ${R}[${Y}08${R}] ${R}» ${C}%-20s${N} %s\n" "V2RAY" "$v2_st"
    printf " ${R}[${Y}09${R}] ${R}» ${C}%-20s${N} %s\n" "HAPROXY MUX" "$haproxy_st"
    printf " ${R}[${Y}10${R}] ${R}» ${C}%-20s${N} %s\n" "SLOWDNS" "$slowdns_st"

    sep
    printf " ${R}[${Y}42${R}] ${R}» ${C}%-20s${N} %s\n" "GESTIÓN CERT SSL" "$ssl_st"
    sep

    echo -e " ${R}[${Y}00${R}] ${R}« VOLVER${N}             ${R}[${Y}100${R}] ${W}AUTO INICIAR${N} ${autostart_st}"
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
      42)   run_proto "Herramientas/ssl.sh" ;;
      100)  
          if grep -q "# --- SN AUTOSTART ---" ~/.bashrc 2>/dev/null; then
              sed -i '/# --- SN AUTOSTART ---/,/# --- END SN ---/d' ~/.bashrc
          else
              {
                echo '# --- SN AUTOSTART ---'
                echo 'if [ "$EUID" -ne 0 ]; then sudo sn; else sn; fi'
                echo '# --- END SN ---'
              } >> ~/.bashrc
          fi
          ;;
      0|00) break ;;
      *) echo -e "${R}Opción inválida${N}"; sleep 1 ;;
    esac
  done
}

main_menu_single
