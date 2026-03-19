#!/bin/bash
set -euo pipefail

# =========================================================
# SinNombre v1.0 - CONFIGURACIÓN DE ZONA HORARIA
# Adaptación visual: @SIN_NOMBRE22
# =========================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── Cargar colores desde lib ────────────────────────────
LIB_COLORES="$ROOT_DIR/lib/colores.sh"
if [[ -f "$LIB_COLORES" ]]; then
  source "$LIB_COLORES"
else
  # Fallback: colores básicos
  R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'
  W='\033[1;37m'; N='\033[0m'; BOLD='\033[1m'
  hr()  { echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"; }
  sep() { echo -e "${R}──────────────────────────────────────────────────────────${N}"; }
  pause() { echo ""; read -r -p "Presiona Enter para continuar..."; }
  clear_screen() { clear; }
fi

# ── Funciones Lógicas ────────────────────────────────────

set_tz() {
  local zona="$1"
  if timedatectl set-timezone "$zona" 2>/dev/null; then
    echo -e "\n  ${G}✓ Zona horaria actualizada a: ${Y}$zona${N}"
    echo -e "  ${W}Hora actual: ${C}$(date)${N}"
  else
    echo -e "\n  ${R}✗ Error al configurar la zona horaria.${N}"
  fi
  pause
}

configure_timezone() {
  while true; do
    clear_screen
    local actual
    actual=$(timedatectl show --property=Timezone --value)

    hr
    echo -e "${W}${BOLD}               CONFIGURAR ZONA HORARIA${N}"
    hr
    echo -e "  ${W}ZONA ACTUAL:${N} ${Y}$actual${N}"
    hr
    echo -e "  ${Y}Selecciona un continente:${N}"
    echo ""
    echo -e "  ${R}[${Y}1${R}]${N} ${C}America${N}     ${R}[${Y}5${R}]${N} ${C}Australia${N}"
    echo -e "  ${R}[${Y}2${R}]${N} ${C}Europe${N}      ${R}[${Y}6${R}]${N} ${C}Atlantic${N}"
    echo -e "  ${R}[${Y}3${R}]${N} ${C}Asia${N}        ${R}[${Y}7${R}]${N} ${C}Pacific${N}"
    echo -e "  ${R}[${Y}4${R}]${N} ${C}Africa${N}      ${R}[${Y}8${R}]${N} ${C}UTC / Otros${N}"
    sep
    echo -e "  ${R}[${Y}0${R}]${N} ${W}VOLVER${N}"
    hr
    echo ""
    echo -ne "  ${W}Elige un continente: ${G}"
    read -r continent

    local prefix=""
    case "$continent" in
      1) prefix="America" ;;
      2) prefix="Europe" ;;
      3) prefix="Asia" ;;
      4) prefix="Africa" ;;
      5) prefix="Australia" ;;
      6) prefix="Atlantic" ;;
      7) prefix="Pacific" ;;
      8) prefix="Etc" ;;
      0) break ;;
      *) echo -e "  ${R}Opción inválida${N}"; sleep 1; continue ;;
    esac

    # Listar zonas del continente elegido
    clear_screen
    hr
    echo -e "${W}${BOLD}       ZONAS DISPONIBLES EN: ${prefix}${N}"
    hr
    
    # Obtenemos las zonas y las mostramos con número
    mapfile -t timezones < <(timedatectl list-timezones | grep "^$prefix/")
    
    for i in "${!timezones[@]}"; do
      printf "  ${R}[${Y}%3d${R}]${N} ${W}%s${N}\n" "$((i+1))" "${timezones[$i]}"
    done | column -c 80  # Esto ayuda a que no sea una lista infinita hacia abajo

    echo ""
    sep
    echo -ne "  ${W}Selecciona el número de tu ciudad: ${G}"
    read -r tz_choice

    if [[ "$tz_choice" =~ ^[0-9]+$ ]] && [ "$tz_choice" -ge 1 ] && [ "$tz_choice" -le "${#timezones[@]}" ]; then
      set_tz "${timezones[$((tz_choice-1))]}"
      break
    else
      echo -e "  ${R}Selección inválida.${N}"
      sleep 1
    fi
  done
}

# ── Ejecución ──────────────────────────────────────────

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo -e "${R}Error: Debes ser root.${N}"
  exit 1
fi

configure_timezone
