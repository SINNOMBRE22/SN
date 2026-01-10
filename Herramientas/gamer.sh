#!/bin/bash

# =========================================================
# MODO GAMER / ACELERADOR DE RED - SinNombre
# (No toca V2Ray/XRay, solo optimiza red del VPS)
# Ubuntu 22.04+
# =========================================================

set -euo pipefail

R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
B='\033[0;34m'
C='\033[0;36m'
W='\033[1;37m'
N='\033[0m'

clear_screen() { clear; }
pause() { echo ""; read -r -p "Presiona Enter para continuar..."; }

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    clear_screen
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${Y}Este menú requiere root.${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    exit 1
  fi
}

hr() { echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"; }

detect_iface() {
  local dev
  dev="$(ip route show default 2>/dev/null | awk '{print $5}' | head -n1 || true)"
  [[ -n "${dev:-}" ]] && echo "$dev" || echo "ens6"
}

IFACE="${IFACE:-$(detect_iface)}"
SYSCTL_FILE="/etc/sysctl.d/99-sn-gamer.conf"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo -e "${Y}Falta comando:${N} ${C}$1${N}"
    pause
    return 1
  }
}

show_status() {
  clear_screen
  hr
  echo -e "${W}                 ESTADO - MODO GAMER${N}"
  hr
  echo -e "${C}Interfaz:${N} ${Y}${IFACE}${N}"
  echo ""

  echo -e "${W}BBR / QDISC (sysctl):${N}"
  sysctl net.ipv4.tcp_congestion_control 2>/dev/null || true
  sysctl net.core.default_qdisc 2>/dev/null || true
  echo ""

  echo -e "${W}Qdisc en ${IFACE}:${N}"
  tc qdisc show dev "$IFACE" 2>/dev/null || echo "(sin datos)"
  echo ""

  echo -e "${W}MSS Clamp (iptables mangle):${N}"
  if iptables -t mangle -S 2>/dev/null | grep -E "TCPMSS|clamp-mss-to-pmtu" >/dev/null; then
    iptables -t mangle -S 2>/dev/null | grep -E "TCPMSS|clamp-mss-to-pmtu" || true
  else
    echo "(sin reglas)"
  fi

  pause
}

apply_bbr() {
  cat >"$SYSCTL_FILE" <<'EOF'
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
  sysctl --system >/dev/null 2>&1 || true
}

remove_bbr() {
  rm -f "$SYSCTL_FILE"
  sysctl --system >/dev/null 2>&1 || true
}

apply_qdisc_fqcodel() {
  # Runtime (hasta reinicio). No persistimos tc para evitar cortes.
  tc qdisc replace dev "$IFACE" root fq_codel >/dev/null 2>&1 || true
}

remove_qdisc() {
  tc qdisc del dev "$IFACE" root >/dev/null 2>&1 || true
}

apply_mss_clamp() {
  iptables -t mangle -C FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || \
    iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

  iptables -t mangle -C OUTPUT -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || \
    iptables -t mangle -A OUTPUT -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
}

remove_mss_clamp() {
  while iptables -t mangle -D FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null; do :; done
  while iptables -t mangle -D OUTPUT  -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null; do :; done
}

install_iptables_persistent() {
  clear_screen
  hr
  echo -e "${W}           GUARDAR REGLAS (iptables-persistent)${N}"
  hr
  echo -e "${Y}Esto mantiene MSS clamp tras reinicio.${N}"
  echo -ne "${W}Continuar? (s/n): ${G}"
  read -r confirm
  [[ "${confirm:-}" != "s" && "${confirm:-}" != "S" ]] && return 0

  apt update -y >/dev/null 2>&1 || true
  DEBIAN_FRONTEND=noninteractive apt install -y iptables-persistent >/dev/null 2>&1 || true
  netfilter-persistent save >/dev/null 2>&1 || true

  echo -e "${G}Listo.${N}"
  pause
}

enable_gamer_full() {
  clear_screen
  hr
  echo -e "${W}              ACTIVAR MODO GAMER (FULL)${N}"
  hr
  echo -e "${Y}Aplica:${N} BBR+fq (persistente) + fq_codel (temporal) + MSS clamp"
  echo -ne "${W}Continuar? (s/n): ${G}"
  read -r confirm
  [[ "${confirm:-}" != "s" && "${confirm:-}" != "S" ]] && return 0

  apply_bbr
  apply_qdisc_fqcodel
  apply_mss_clamp

  echo -e "${G}Modo Gamer FULL activado.${N}"
  echo -e "${Y}Nota:${N} fq_codel se reinicia al reboot. BBR queda persistente."
  pause
}

enable_gamer_light() {
  clear_screen
  hr
  echo -e "${W}            ACTIVAR MODO GAMER (LIGERO)${N}"
  hr
  echo -e "${Y}Aplica:${N} BBR+fq (persistente) + MSS clamp (sin qdisc)"
  echo -ne "${W}Continuar? (s/n): ${G}"
  read -r confirm
  [[ "${confirm:-}" != "s" && "${confirm:-}" != "S" ]] && return 0

  apply_bbr
  apply_mss_clamp

  echo -e "${G}Modo Gamer LIGERO activado.${N}"
  pause
}

disable_all() {
  clear_screen
  hr
  echo -e "${W}                 DESACTIVAR / REVERTIR${N}"
  hr
  echo -e "${Y}Esto quitará:${N} BBR sysctl + qdisc + MSS clamp"
  echo -ne "${W}Continuar? (s/n): ${G}"
  read -r confirm
  [[ "${confirm:-}" != "s" && "${confirm:-}" != "S" ]] && return 0

  remove_bbr
  remove_qdisc
  remove_mss_clamp

  echo -e "${G}Revertido a estado normal.${N}"
  pause
}

main_menu() {
  require_root
  need_cmd ip || exit 0
  need_cmd tc || exit 0
  need_cmd sysctl || exit 0
  need_cmd iptables || exit 0

  while true; do
    clear_screen
    hr
    echo -e "${W}           MODO GAMER / ACELERADOR DE RED${N}"
    hr
    echo -e "${C}Interfaz detectada:${N} ${Y}${IFACE}${N}"
    echo ""
    echo -e "${R}[${Y}1${R}]${N}  ${C}Ver Estado${N}"
    echo -e "${R}───────────────────────────────────────────────────────────${N}"
    echo -e "${R}[${Y}2${R}]${N}  ${C}Activar Modo Gamer (FULL)${N}"
    echo -e "${R}───────────────────────────────────────────────────────────${N}"
    echo -e "${R}[${Y}3${R}]${N}  ${C}Activar Modo Gamer (Ligero)${N}"
    echo -e "${R}───────────────────────────────────────────────────────────${N}"
    echo -e "${R}[${Y}4${R}]${N}  ${C}Guardar reglas (iptables-persistent)${N}"
    echo -e "${R}───────────────────────────────────────────────────────────${N}"
    echo -e "${R}[${Y}5${R}]${N}  ${C}Desactivar / Revertir todo${N}"
    echo -e "${R}───────────────────────────────────────────────────────────${N}"
    echo -e "${R}[${Y}0${R}]${N}  ${C}VOLVER${N}"
    hr
    echo ""
    echo -ne "${W}Selecciona una opción: ${G}"
    read -r option

    case "${option:-}" in
      1) show_status ;;
      2) enable_gamer_full ;;
      3) enable_gamer_light ;;
      4) install_iptables_persistent ;;
      5) disable_all ;;
      0) return 0 ;;
      *) echo -e "${B}Opción inválida${N}"; sleep 2 ;;
    esac
  done
}

trap return SIGINT SIGTERM
main_menu
