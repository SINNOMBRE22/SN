#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# =========================================================
# SinNombre v1.3 - ADMINISTRAR PUERTOS (Ubuntu/Debian)
# - Lista puertos en escucha (ss)
# - Detecta proceso, PID y unidad systemd (si aplica)
# - Permite:
#     1) DESACTIVAR (stop + disable + matar PIDs)
#     2) ELIMINAR   (detectar paquete real por /proc/PID/exe + dpkg -S, y purgarlo)
# =========================================================

R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
C='\033[0;36m'
W='\033[1;37m'
N='\033[0m'

pause(){ echo ""; read -r -p "Presiona Enter para continuar..."; }
hr(){ echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"; }
sep(){ echo -e "${R}------------------------------------------------------------${N}"; }
require_root(){ [[ "${EUID:-$(id -u)}" -eq 0 ]] || { echo -e "${R}Ejecuta como root.${N}"; exit 1; }; }

require_debian_family(){
  command -v dpkg-query &>/dev/null || { echo -e "${R}Este script es para Ubuntu/Debian (dpkg no encontrado).${N}"; exit 1; }
  command -v apt-get &>/dev/null || { echo -e "${R}apt-get no encontrado.${N}"; exit 1; }
}

# Globals construidos por show_services_status()
declare -gA services_ports=()   # display -> "22, 80"
declare -gA services_pids=()    # display -> "123, 456"
declare -gA services_proc=()    # display -> "sshd"
declare -gA services_unit=()    # display -> "ssh.service"
declare -gA services_exe=()     # display -> "/usr/sbin/sshd" (primero encontrado)
declare -gA services_pkg=()     # display -> "openssh-server"
declare -ga services_list=()    # lista ordenada de display

is_critical_ports() {
  local ports="${1:-}"
  [[ ", ${ports}, " == *", 22, "* ]]
}

add_unique_csv() {
  local existing="${1:-}"
  local value="${2:-}"
  if [[ -z "$existing" ]]; then
    echo "$value"; return 0
  fi
  [[ ", ${existing}, " == *", ${value}, "* ]] && { echo "$existing"; return 0; }
  echo "${existing}, ${value}"
}

get_systemd_unit_by_pid() {
  local pid="${1:-}"
  [[ -n "$pid" ]] || { echo ""; return 0; }

  local unit=""
  unit="$(systemctl show -p Unit --value "$pid" 2>/dev/null || true)"

  # Fallback: procps (en muchos Ubuntu/Debian modernos)
  if [[ -z "$unit" ]] && command -v ps &>/dev/null; then
    unit="$(ps -o unit= -p "$pid" 2>/dev/null | awk '{$1=$1;print}' || true)"
  fi

  [[ "$unit" == "-" ]] && unit=""
  echo "$unit"
}

get_service_display_name() {
  local proc="$1"
  local unit="$2"
  if [[ -n "${unit:-}" ]]; then
    echo "${unit%.service}"
  else
    echo "$proc"
  fi
}

get_exe_by_pid() {
  local pid="${1:-}"
  [[ -n "$pid" ]] || { echo ""; return 0; }
  readlink -f "/proc/$pid/exe" 2>/dev/null || echo ""
}

get_pkg_by_exe() {
  local exe="${1:-}"
  [[ -n "$exe" ]] || { echo ""; return 0; }

  # dpkg-query -S puede devolver múltiples líneas; tomamos la primera
  # formato: paquete: ruta
  dpkg-query -S "$exe" 2>/dev/null | head -n1 | awk -F: '{print $1}' || true
}

confirm_if_critical() {
  local ports="$1"
  local word="$2"
  if is_critical_ports "$ports"; then
    echo -e "${R}CRÍTICO:${N} Esto usa el puerto 22 (SSH). Puedes perder acceso."
    echo -ne "${Y}Confirmación extra: escribe EXACTAMENTE '${word}': ${N}"
    local c; read -r c
    [[ "$c" == "$word" ]] || { echo -e "${Y}Cancelado.${N}"; return 1; }
  fi
  return 0
}

kill_pids_of_service() {
  local service="$1"
  local pids="${services_pids[$service]:-}"
  [[ -n "$pids" ]] || return 0

  local pid_list="${pids//,/}"
  for pid in $pid_list; do
    [[ "$pid" =~ ^[0-9]+$ ]] || continue
    kill "$pid" 2>/dev/null || true
  done
  sleep 0.2
  for pid in $pid_list; do
    [[ "$pid" =~ ^[0-9]+$ ]] || continue
    kill -9 "$pid" 2>/dev/null || true
  done
}

stop_disable_by_service() {
  local service="$1"
  local unit="${services_unit[$service]:-}"

  if command -v systemctl &>/dev/null && [[ -n "$unit" ]]; then
    systemctl stop "$unit" 2>/dev/null || true
    systemctl disable "$unit" 2>/dev/null || true
    return 0
  fi

  # fallback por nombre
  if command -v systemctl &>/dev/null; then
    systemctl stop "${service}.service" 2>/dev/null || systemctl stop "$service" 2>/dev/null || true
    systemctl disable "${service}.service" 2>/dev/null || systemctl disable "$service" 2>/dev/null || true
  fi
}

show_services_status() {
  services_ports=()
  services_pids=()
  services_proc=()
  services_unit=()
  services_exe=()
  services_pkg=()
  services_list=()

  echo -e "${R}PRECAUCIÓN:${N} no desactives/eliminines SSH (puerto 22) si es tu acceso."
  hr
  echo -e "${W}                 SERVICIOS / PUERTOS ACTIVOS${N}"
  hr

  local lines
  lines="$(ss -H -lntup 2>/dev/null || true)"

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    local port proc pid unit service exe pkg

    # Puerto (soporta [::]:22)
    port="$(awk '{print $5}' <<<"$line" | awk -F':' '{print $NF}')"
    port="${port//[/}"; port="${port//]/}"
    [[ -n "$port" && "$port" =~ ^[0-9]+$ ]] || continue

    proc="$(sed -n 's/.*users:(("\([^"]*\)".*/\1/p' <<<"$line" || true)"
    pid="$(sed -n 's/.*pid=\([0-9]\+\).*/\1/p' <<<"$line" || true)"
    [[ -n "${proc:-}" ]] || proc="Desconocido"

    unit=""
    [[ -n "${pid:-}" ]] && unit="$(get_systemd_unit_by_pid "$pid")"

    service="$(get_service_display_name "$proc" "$unit")"
    [[ -n "${service:-}" ]] || service="Desconocido"

    services_ports["$service"]="$(add_unique_csv "${services_ports[$service]:-}" "$port")"
    services_proc["$service"]="$proc"
    [[ -n "${pid:-}" ]] && services_pids["$service"]="$(add_unique_csv "${services_pids[$service]:-}" "$pid")"
    [[ -n "${unit:-}" ]] && services_unit["$service"]="$unit"

    # Capturar exe y paquete (solo el primero que encontremos)
    if [[ -n "${pid:-}" && -z "${services_exe[$service]:-}" ]]; then
      exe="$(get_exe_by_pid "$pid")"
      if [[ -n "$exe" ]]; then
        services_exe["$service"]="$exe"
        pkg="$(get_pkg_by_exe "$exe")"
        [[ -n "$pkg" ]] && services_pkg["$service"]="$pkg"
      fi
    fi
  done <<< "$lines"

  local count="${#services_ports[@]}"
  if [[ "$count" -eq 0 ]]; then
    echo -e "${Y}No se encontraron servicios activos.${N}"
    hr
    return 1
  fi

  mapfile -t services_list < <(printf '%s\n' "${!services_ports[@]}" | LC_ALL=C sort)

  local total=${#services_list[@]}
  local half=$(( (total + 1) / 2 ))

  for ((i = 0; i < half; i++)); do
    local s1="${services_list[$i]}"
    local left="${s1}: ${services_ports[$s1]}"
    printf "${G}[%d]${N} ${C}%-36s${N}" "$((i+1))" "$left"

    if [[ $((i + half)) -lt total ]]; then
      local idx=$((i + half))
      local s2="${services_list[$idx]}"
      local right="${s2}: ${services_ports[$s2]}"
      printf "  ${G}[%d]${N} ${C}%-36s${N}" "$((idx+1))" "$right"
    fi
    echo ""
  done

  hr
  return 0
}

disable_service() {
  local service="$1"
  local ports="$2"

  confirm_if_critical "$ports" "DESACTIVAR" || return 0

  echo -e "${Y}Desactivando:${N} ${C}${service}${N}"
  stop_disable_by_service "$service"
  kill_pids_of_service "$service"
  echo -e "${G}Desactivado:${N} ${C}${service}${N}"
}

remove_service() {
  local service="$1"
  local ports="$2"

  echo -e "${R}ADVERTENCIA:${N} esto va a purgar un paquete (Ubuntu/Debian)."
  confirm_if_critical "$ports" "ELIMINAR" || return 0

  local unit="${services_unit[$service]:-}"
  local proc="${services_proc[$service]:-}"
  local pids="${services_pids[$service]:-}"
  local exe="${services_exe[$service]:-}"
  local pkg="${services_pkg[$service]:-}"

  echo -e "${W}Objetivo:${N} ${C}${service}${N}"
  [[ -n "$unit" ]] && echo -e "${W}Unit:${N}    ${C}${unit}${N}"
  [[ -n "$proc" ]] && echo -e "${W}Proc:${N}    ${C}${proc}${N}"
  [[ -n "$pids" ]] && echo -e "${W}PIDs:${N}    ${C}${pids}${N}"
  [[ -n "$exe"  ]] && echo -e "${W}EXE:${N}     ${C}${exe}${N}"
  [[ -n "$pkg"  ]] && echo -e "${W}Paquete:${N} ${G}${pkg}${N}"

  if [[ -z "$pkg" ]]; then
    echo -e "${R}No se pudo detectar el paquete de forma segura.${N}"
    echo -e "${Y}Acción:${N} se desactivará y matará el proceso, pero NO se purgará nada."
    stop_disable_by_service "$service"
    kill_pids_of_service "$service"
    return 0
  fi

  echo -ne "${Y}¿Purgar paquete '${pkg}'? (s/n): ${N}"
  local confirm_pkg; read -r confirm_pkg
  [[ "$confirm_pkg" =~ ^[sS]$ ]] || { echo -e "${Y}Cancelado.${N}"; return 0; }

  # Detener primero
  stop_disable_by_service "$service"
  kill_pids_of_service "$service"

  # Purgar paquete real
  apt-get purge -y "$pkg"
  apt-get autoremove -y || true

  # Recargar systemd
  systemctl daemon-reload 2>/dev/null || true

  echo -e "${G}Paquete purgado:${N} ${C}${pkg}${N}"
}

manage_service_menu() {
  local service="$1"
  local ports="$2"

  local proc="${services_proc[$service]:-}"
  local pids="${services_pids[$service]:-}"
  local unit="${services_unit[$service]:-}"
  local exe="${services_exe[$service]:-}"
  local pkg="${services_pkg[$service]:-}"

  clear
  hr
  echo -e "${W}GESTIONAR:${N} ${C}${service}${N}"
  echo -e "${W}PUERTOS:${N}   ${G}${ports}${N}"
  [[ -n "$unit" ]] && echo -e "${W}UNIT:${N}     ${C}${unit}${N}"
  [[ -n "$proc" ]] && echo -e "${W}PROC:${N}     ${C}${proc}${N}"
  [[ -n "$pids" ]] && echo -e "${W}PIDS:${N}     ${C}${pids}${N}"
  [[ -n "$exe"  ]] && echo -e "${W}EXE:${N}      ${C}${exe}${N}"
  [[ -n "$pkg"  ]] && echo -e "${W}PAQUETE:${N}  ${G}${pkg}${N}"
  hr

  echo -e "${R}[${Y}1${R}]${N} ${C}Desactivar${N}"
  echo -e "${R}[${Y}2${R}]${N} ${C}Eliminar (purga paquete real)${N}"
  echo -e "${R}[${Y}0${R}]${N} ${W}Volver${N}"
  hr
  echo -ne "${W}Opción: ${G}"
  read -r action

  case "${action:-}" in
    1) disable_service "$service" "$ports" ;;
    2) remove_service "$service" "$ports" ;;
    0) return 0 ;;
    *) echo -e "${R}Opción inválida.${N}" ;;
  esac

  pause
}

main_menu() {
  require_root
  require_debian_family

  while true; do
    clear
    show_services_status || { pause; return 0; }

    echo -e "${Y}Selecciona el número del servicio (0 para salir):${N}"
    echo -ne "${W}Número: ${G}"
    read -r choice

    [[ "${choice:-}" == "0" ]] && exit 0

    if [[ ! "${choice:-}" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#services_list[@]} )); then
      echo -e "${R}Número inválido.${N}"
      pause
      continue
    fi

    local service="${services_list[$((choice - 1))]}"
    local ports="${services_ports[$service]}"

    manage_service_menu "$service" "$ports"
  done
}

main_menu
