#!/bin/bash
set -euo pipefail

# =========================================================
# SinNombre v1.0 - ADMINISTRADOR SSH
# Archivo: SN/Protocolos/ssh.sh
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

# ── Utilidades de Servicio ───────────────────────────────

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo -e "${R}Error: Ejecuta como root.${N}"
    exit 1
  fi
}

ssh_service_name() {
  if systemctl list-unit-files 2>/dev/null | awk '{print $1}' | grep -qx 'ssh.service'; then
    echo "ssh"
  else
    echo "sshd"
  fi
}

ssh_is_on() {
  local svc
  svc="$(ssh_service_name)"
  systemctl is-active --quiet "$svc" 2>/dev/null
}

ssh_badge() {
  if ssh_is_on; then
    echo -e "${G}[ ON ]${N}"
  else
    echo -e "${R}[ OFF ]${N}"
  fi
}

get_ssh_ports_compact() {
  local ports
  ports="$(ss -H -lntp 2>/dev/null | awk '$0 ~ /(sshd|ssh)/ {print $4}' | awk -F: '{print $NF}' | sort -n | uniq | tr '\n' ' ' | sed 's/[[:space:]]\+$//' || true)"
  [[ -n "${ports:-}" ]] && echo "$ports" || echo "22"
}

# ── Acciones ─────────────────────────────────────────────

change_ssh_port() {
  clear_screen
  hr
  echo -e "${W}               MODIFICAR PUERTO SSH${N}"
  hr
  echo ""
  echo -ne "  ${W}Nuevo puerto SSH: ${G}"
  read -r newp
  echo -ne "${N}"
  [[ "${newp:-}" =~ ^[0-9]+$ ]] || { echo -e "  ${R}✗ Puerto inválido.${N}"; pause; return; }
  (( newp >= 1 && newp <= 65535 )) || { echo -e "  ${R}✗ Puerto fuera de rango.${N}"; pause; return; }

  local cfg="/etc/ssh/sshd_config"
  [[ -f "$cfg" ]] || { echo -e "  ${R}✗ No existe $cfg${N}"; pause; return; }

  echo ""
  echo -ne "  ${W}¿Confirmas cambiar SSH al puerto ${Y}${newp}${W}? (s/n): ${G}"
  read -r yn
  echo -ne "${N}"
  [[ "${yn,,}" == "s" ]] || { echo -e "  ${Y}Cancelado.${N}"; pause; return; }

  cp -a "$cfg" "${cfg}.bak.$(date +%F_%H%M%S)"

  if grep -qiE '^[[:space:]]*Port[[:space:]]+' "$cfg"; then
    sed -i -E "s/^[[:space:]]*Port[[:space:]]+.*/Port ${newp}/I" "$cfg"
  else
    echo "" >> "$cfg"
    echo "Port ${newp}" >> "$cfg"
  fi

  if sshd -t 2>/dev/null; then
    systemctl restart "$(ssh_service_name)" 2>/dev/null || true
    echo -e "  ${G}✓ Puerto SSH actualizado y servicio reiniciado.${N}"
    echo -e "  ${Y}⚠ Recuerda abrir el puerto ${newp} en tu firewall.${N}"
  else
    echo -e "  ${R}✗ Configuración inválida. Revirtiendo cambios...${N}"
    local lastbak
    lastbak="$(ls -1t "${cfg}.bak."* 2>/dev/null | head -n1 || true)"
    [[ -n "${lastbak:-}" ]] && cp -a "$lastbak" "$cfg" || true
  fi
  pause
}

config_key_root() {
  clear_screen
  hr
  echo -e "${W}        CONFIGURAR CLAVE Y ACCESO ROOT${N}"
  hr
  echo -e "  ${Y}Módulo en desarrollo...${N}"
  pause
}

toggle_ssh_service() {
  local svc
  svc="$(ssh_service_name)"
  if ssh_is_on; then
    systemctl stop "$svc" >/dev/null 2>&1 || true
    systemctl disable "$svc" >/dev/null 2>&1 || true
  else
    systemctl enable "$svc" >/dev/null 2>&1 || true
    systemctl start "$svc" >/dev/null 2>&1 || true
  fi
}

uninstall_openssh() {
  clear_screen
  hr
  echo -e "${R}           DESINSTALAR OPENSSH-SERVER${N}"
  hr
  echo -e "  ${Y}⚠ Advertencia:${N} ${W}Si desinstalas OpenSSH perderás el acceso remoto.${N}"
  echo ""
  echo -ne "  ${W}¿Confirmas la desinstalación? (s/n): ${G}"
  read -r yn
  echo -ne "${N}"
  [[ "${yn,,}" == "s" ]] || { echo -e "  ${Y}Cancelado.${N}"; pause; return; }

  apt-get remove -y openssh-server >/dev/null 2>&1 || true
  apt-get autoremove -y >/dev/null 2>&1 || true
  echo -e "  ${G}✓ OpenSSH-Server desinstalado.${N}"
  pause
}

# ── Menú Principal ───────────────────────────────────────

main_menu() {
  require_root

  while true; do
    clear_screen
    local ports st
    ports="$(get_ssh_ports_compact)"
    st="$(ssh_badge)"

    hr
    echo -e "${W}                 ADMINISTRADOR SSH${N}"
    hr
    echo -e "  ${W}PUERTOS ACTUALES:${N} ${Y}${ports}${N}"
    hr
    echo ""
    echo -e "  ${R}[${Y}1${R}]${N} ${C}MODIFICAR PUERTO SSH${N}"
    echo -e "  ${R}[${Y}2${R}]${N} ${C}CONFIGURAR CLAVE Y ACCESO ROOT${N}"
    sep
    echo -e "  ${R}[${Y}4${R}]${N} ${C}INICIAR / DETENER SSH${N}   ${st}"
    echo -e "  ${R}[${Y}5${R}]${N} ${C}REINICIAR SERVIDOR SSH${N}"
    sep
    echo -e "  ${R}[${Y}6${R}]${N} ${C}DESINSTALAR OPENSSH-SERVER${N}"
    hr
    echo -e "  ${R}[${Y}0${R}]${N} ${W}VOLVER${N}"
    hr
    echo ""
    echo -ne "  ${W}Seleccione una opción: ${G}"
    read -r op
    echo -ne "${N}"

    case "${op:-}" in
      1) change_ssh_port ;;
      2) config_key_root ;;
      4) toggle_ssh_service ;;
      5) systemctl restart "$(ssh_service_name)" 2>/dev/null; echo -e "  ${G}✓ Servicio reiniciado.${N}"; sleep 1 ;;
      6) uninstall_openssh ;;
      0) break ;;
      *) echo -e "  ${R}Opción inválida${N}"; sleep 1 ;;
    esac
  done
}

main_menu
