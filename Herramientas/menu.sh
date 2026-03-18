#!/bin/bash

# =========================================================
# SinNombre v2.0 - Menú de Herramientas (Ubuntu 22.04+)
# Creador: @SIN_NOMBRE22
# =========================================================

# Cargar colores y funciones compartidas
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/colores.sh" 2>/dev/null \
  || source "/etc/SN/lib/colores.sh" 2>/dev/null || true

# ===== RUTAS Y VARIABLES =====
VPS_src="/etc/SN"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
L_ROJA="${R}══════════════════════════ / / / ══════════════════════════${N}"

# ===== FUNCIONES INTEGRADAS =====

update_system() {
  header "       ACTUALIZAR SISTEMA"
  echo -e "${Y}Actualizando paquetes...${N}"
  apt update && apt upgrade -y
  echo -e "${G}Sistema actualizado.${N}"
  pause
}

clean_cache() {
  header "         LIMPIAR CACHE"
  apt clean && apt autoclean
  rm -rf ~/.cache/thumbnails/*
  echo -e "${G}Cache limpiado.${N}"
  pause
}

change_root_pass() {
  header "    CAMBIAR CONTRASEÑA ROOT"
  passwd root
  pause
}

configure_domain() {
  header "     CONFIGURAR DOMINIO VPS"
  mkdir -p "$VPS_src"
  echo -ne "${W}Ingresa el dominio de la VPS: ${G}"
  read -r domain
  if [[ -n "${domain:-}" ]]; then
    echo "$domain" > "${VPS_src}/dominio.txt"
    echo -e "${G}Dominio configurado: $domain${N}"
  else
    echo -e "${Y}No se ingresó dominio.${N}"
  fi
  pause
}

restart_services() {
  header "       REINICIAR SERVICIOS"
  systemctl restart sshd 2>/dev/null || true
  systemctl restart cron 2>/dev/null || true
  systemctl restart rsyslog 2>/dev/null || true
  echo -e "${G}Servicios reiniciados.${N}"
  pause
}

# ===== MENÚ PRINCIPAL =====

main_menu() {
  while true; do
    clear_screen
    echo -e "$L_ROJA"
    echo -e "${W}                        HERRAMIENTAS${N}"
    echo -e "$L_ROJA"

    # Flechas Rojas (${R}), Nombres Aqua (${C})
    echo -e " ${R}[${Y}01${R}] ${R}» ${C}LIMPIAR CACHE         ${R}[${Y}05${R}] ${R}» ${C}CAMBIAR PASS ROOT${N}"
    echo -e " ${R}[${Y}02${R}] ${R}» ${C}GESTION SWAP          ${R}[${Y}06${R}] ${R}» ${C}CONFIGURAR DOMINIO${N}"
    echo -e " ${R}[${Y}03${R}] ${R}» ${C}REINICIAR SERVICIOS   ${R}[${Y}07${R}] ${R}» ${C}ZONA HORARIA${N}"
    echo -e " ${R}[${Y}04${R}] ${R}» ${C}ACTUALIZAR SISTEMA${N}"
    
    echo -e "${R}───────────────────────────────────────────────────────────${N}"
    # Opción Salir en Rojo
    echo -e " ${R}[${Y}00${R}] ${R}« SALIR${N}"
    echo -e "$L_ROJA"
    
    # Apartado de selección estilo profesional en Verde
    echo ""
    echo -ne "${W}┌─[${G}${BOLD}Seleccione una opción${W}]${N}\n"
    echo -ne "╰─> : ${G}"
    read -r op
    echo -ne "${N}"

    case "${op:-}" in
      1|01) clean_cache ;;
      2|02) run_module "swap.sh" "$ROOT_DIR" ;;
      3|03) restart_services ;;
      4|04) update_system ;;
      5|05) change_root_pass ;;
      6|06) configure_domain ;;
      7|07) run_module "zonahora.sh" "$ROOT_DIR" ;;
      0|00) exit 0 ;;
      *) echo -e "${R} Opción inválida${N}"; sleep 1 ;;
    esac
  done
}

# Verificación Root
require_root

main_menu
