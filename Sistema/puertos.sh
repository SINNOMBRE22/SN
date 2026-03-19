#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# =========================================================
# SinNombre v1.6 - ADMINISTRADOR INTEGRAL DE PUERTOS
# =========================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── Cargar colores desde lib ────────────────────────────
LIB_COLORES="$ROOT_DIR/lib/colores.sh"
if [[ -f "$LIB_COLORES" ]]; then
  source "$LIB_COLORES"
else
  R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'; W='\033[1;37m'; N='\033[0m'
  hr(){ echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"; }
  sep(){ echo -e "${R}──────────────────────────────────────────────────────────${N}"; }
fi

# Variables Globales
declare -gA services_ports=()
declare -gA services_pids=()
services_list=()

# ── Funciones de Rastreo ────────────────────────────────

get_systemd_unit_by_pid() {
  local unit
  unit="$(systemctl show -p Unit --value "$1" 2>/dev/null || true)"
  [[ "$unit" == "-" ]] && unit=""
  echo "$unit"
}

get_exe_by_pid() {
  readlink -f "/proc/${1}/exe" 2>/dev/null || echo ""
}

get_pkg_by_exe() {
  [[ -z "$1" ]] && return
  dpkg-query -S "$1" 2>/dev/null | head -n1 | awk -F: '{print $1}' || echo ""
}

# ── Gestión de Servicio (Purgar/Detener) ────────────────

manage_service() {
  local service="$1"
  local ports="${services_ports[$service]:-Desconocidos}"
  local pids="${services_pids[$service]%,}"
  
  # Obtener info extra para la gestión
  local first_pid=$(echo "$pids" | cut -d',' -f1)
  local exe=$(get_exe_by_pid "$first_pid")
  local pkg=$(get_pkg_by_exe "$exe")

  clear
  hr
  echo -e "${W}${BOLD}              GESTIONAR: ${C}${service}${N}"
  hr
  echo -e "  ${W}PUERTOS:${N}  ${G}${ports}${N}"
  [[ -n "$exe" ]] && echo -e "  ${W}ARCHIVO:${N}  ${W}${exe}${N}"
  [[ -n "$pkg" ]] && echo -e "  ${W}PAQUETE:${N}  ${Y}${pkg}${N}"
  sep
  echo -e "  ${R}[${Y}1${R}]${N} ${C}DESACTIVAR${N} (Stop/Kill)"
  echo -e "  ${R}[${Y}2${R}]${N} ${R}ELIMINAR${N} (Purgar paquete)"
  echo -e "  ${R}[${Y}0${R}]${N} ${W}VOLVER AL MENÚ${N}"
  sep
  echo -ne "  ${W}Opción: ${G}"
  read -r op

  case "$op" in
    1)
      echo -e "  ${Y}Deteniendo servicio...${N}"
      systemctl stop "$service" 2>/dev/null || true
      IFS=',' read -ra pid_arr <<< "$pids"
      for p in "${pid_arr[@]}"; do kill -9 "$p" 2>/dev/null || true; done
      echo -e "  ${G}✓ Procesos eliminados.${N}"
      sleep 1 ;;
    2)
      if [[ -n "$pkg" ]]; then
        echo -ne "  ${R}⚠ ¿Confirmas purgar ${pkg}? (s/n): ${N}"
        read -r conf
        if [[ "$conf" == "s" || "$conf" == "S" ]]; then
          apt-get purge -y "$pkg" && apt-get autoremove -y
          echo -e "  ${G}✓ Paquete purgado.${N}"
        fi
      else
        echo -e "  ${R}✗ No se detectó un paquete APT para este servicio.${N}"
      fi
      sleep 1 ;;
    0) return ;;
  esac
}

# ── Visualización de Puertos ────────────────────────────

show_all_ports() {
  services_ports=(); services_pids=(); services_list=()
  local lines
  lines="$(ss -H -lntup 2>/dev/null || true)"

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local port proc pid unit service
    port="$(awk '{print $5}' <<<"$line" | awk -F':' '{print $NF}')"
    port="${port//[/}"; port="${port//]/}"
    [[ -n "$port" && "$port" =~ ^[0-9]+$ ]] || continue

    proc="$(sed -n 's/.*users:(("\([^"]*\)".*/\1/p' <<<"$line" || true)"
    pid="$(sed -n 's/.*pid=\([0-9]\+\).*/\1/p' <<<"$line" || true)"
    
    unit="$(get_systemd_unit_by_pid "$pid")"
    [[ -n "$unit" ]] && service="${unit%.service}" || service="${proc:-Desconocido}"

    if [[ -z "${services_ports[$service]:-}" ]]; then
        services_ports["$service"]="$port"
    elif [[ ", ${services_ports[$service]}, " != *", ${port}, "* ]]; then
        services_ports["$service"]="${services_ports[$service]}, $port"
    fi
    [[ -n "$pid" ]] && services_pids["$service"]="${services_pids[$service]:-}${pid},"
  done <<< "$lines"

  mapfile -t services_list < <(printf '%s\n' "${!services_ports[@]}" | sort)

  while true; do
    clear
    hr
    echo -e "${W}${BOLD}                 LISTA COMPLETA DE PUERTOS${N}"
    hr
    local count=1
    for s in "${services_list[@]}"; do
      local p_disp="${services_ports[$s]}"
      [[ ${#p_disp} -gt 35 ]] && p_disp="${p_disp:0:32}..."
      printf "  ${R}[${Y}%2d${R}]${N} ${C}%-18s${N} -> ${G}%s${N}\n" "$count" "${s:0:18}" "$p_disp"
      ((count++))
    done
    sep
    echo -ne "  ${W}Selecciona un ID para gestionar (0 para volver): ${G}"
    read -r choice
    [[ "$choice" == "0" ]] && break
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#services_list[@]} )); then
      manage_service "${services_list[$((choice-1))]}"
      break # Volver al menú tras gestionar
    fi
  done
}

# ── Buscador ────────────────────────────────────────────

search_port() {
  clear
  hr
  echo -e "${W}${BOLD}                BUSCADOR DE PUERTOS / NOMBRES${N}"
  hr
  echo -ne "  ${W}Ingrese término de búsqueda: ${G}"
  read -r term
  [[ -z "$term" ]] && return
  
  # Si es un puerto, buscamos info detallada
  if [[ "$term" =~ ^[0-9]+$ ]]; then
     local line=$(ss -lntup | grep ":$term " | head -n1)
     if [[ -n "$line" ]]; then
        local pid=$(echo "$line" | sed -n 's/.*pid=\([0-9]\+\).*/\1/p')
        local proc=$(echo "$line" | sed -n 's/.*users:(("\([^"]*\)".*/\1/p')
        local unit=$(get_systemd_unit_by_pid "$pid")
        [[ -n "$unit" ]] && service="${unit%.service}" || service="$proc"
        
        # Guardar en arrays para poder gestionar
        services_ports["$service"]="$term"
        services_pids["$service"]="$pid,"
        
        echo -e "  ${G}Puerto encontrado!${N}"
        manage_service "$service"
     else
        echo -e "  ${R}Puerto no encontrado.${N}"; sleep 1
     fi
  else
     # Si es nombre, filtramos la lista completa
     SEARCH_FILTER="$term"
     show_all_ports # Reutilizamos la lista pero el usuario verá lo que busca
  fi
}

# ── Menú Principal ──────────────────────────────────────

while true; do
  clear
  hr
  echo -e "${W}${BOLD}               ADMINISTRADOR DE RED SN-PLUS${N}"
  hr
  echo -e "  ${R}[${Y}1${R}]${N} ${C}VER TODOS LOS PUERTOS${N}"
  echo -e "  ${R}[${Y}2${R}]${N} ${C}BUSCAR PUERTO O SERVICIO${N}"
  echo -e "  ${R}[${Y}0${R}]${N} ${W}SALIR${N}"
  hr
  echo -ne "  ${W}Selecciona: ${G}"
  read -r opt
  case "$opt" in
    1) show_all_ports ;;
    2) search_port ;;
    0) exit 0 ;;
    *) echo -e "  ${R}Opción inválida.${N}"; sleep 1 ;;
  esac
done
