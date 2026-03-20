#!/bin/bash
# =========================================================
# SinNombre v2.1 - Menú de Herramientas (Ubuntu 22.04+)
# =========================================================

# ------------------------------------------------------------------
# 1. Carga robusta de la librería de colores (funciona en /root/SN o /etc/SN)
# ------------------------------------------------------------------
find_colores() {
    local posibles=(
        "/root/SN/lib/colores.sh"
        "/etc/SN/lib/colores.sh"
        "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/colores.sh"
        "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/colores.sh"
    )
    for path in "${posibles[@]}"; do
        if [[ -f "$path" ]]; then
            echo "$path"
            return 0
        fi
    done
    return 1
}

LIB_COLORES=$(find_colores)
if [[ -f "$LIB_COLORES" ]]; then
    source "$LIB_COLORES"
else
    # Fallback: definimos las funciones mínimas necesarias (colores básicos)
    R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; B='\033[0;34m'
    M='\033[0;35m'; C='\033[0;36m'; W='\033[1;37m'; N='\033[0m'
    BOLD='\033[1m'
    hr()  { echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"; }
    sep() { echo -e "${R}──────────────────────────────────────────────────────────${N}"; }
    step() { printf " ${C}•${N} ${W}%s${N} " "$1"; }
    ok()   { echo -e "${G}[OK]${N}"; }
    fail() { echo -e "${R}[FAIL]${N}"; }
    pause() { echo ""; read -r -p "Presiona Enter para continuar..."; }
    clear_screen() { clear; }
    msg() {
        case "$1" in
            -bar)   hr ;;
            -bar3)  sep ;;
            -azu)   shift; echo -e "${C}$*${N}" ;;
            -verd)  shift; echo -e "${G}$*${N}" ;;
            -verm)  shift; echo -e "${R}$*${N}" ;;
            -ama)   shift; echo -e "${Y}$*${N}" ;;
            *)      echo -e "$*" ;;
        esac
    }
    title() { clear_screen; hr; echo -e "${W}    $* ${N}"; hr; }
    print_center() { echo -e "$*"; }
    enter() { echo ""; read -r -p " Presione ENTER para continuar"; }
    del() { local lines="${1:-1}"; for ((i=0;i<lines;i++)); do tput cuu1 2>/dev/null; tput el 2>/dev/null; done; }
fi

# ------------------------------------------------------------------
# 2. Variables de entorno
# ------------------------------------------------------------------
VPS_src="/etc/SN"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ------------------------------------------------------------------
# 3. Funciones del menú (pueden estar definidas aquí o en módulos externos)
# ------------------------------------------------------------------
run_module() {
  local script_name="$1"
  local script_path="$2/$script_name"
  if [[ -f "$script_path" ]]; then
    chmod +x "$script_path"
    bash "$script_path"
  else
    echo -e "${R} Error: No se encontró $script_name${N}"; sleep 2
  fi
}

# Funciones de herramientas (si no están definidas en otro lugar, se implementan aquí)
clean_cache() {
    # Limpia caché del sistema (ejemplo)
    echo -e "${Y}Limpiando caché...${N}"
    sync && echo 3 > /proc/sys/vm/drop_caches
    echo -e "${G}Caché limpiada.${N}"
    pause
}

restart_services() {
    # Reinicia servicios comunes
    echo -e "${Y}Reiniciando servicios...${N}"
    systemctl restart sshd 2>/dev/null || true
    systemctl restart dropbear 2>/dev/null || true
    systemctl restart stunnel4 2>/dev/null || true
    systemctl restart squid 2>/dev/null || true
    echo -e "${G}Servicios reiniciados.${N}"
    pause
}

update_system() {
    echo -e "${Y}Actualizando sistema...${N}"
    apt update && apt upgrade -y
    echo -e "${G}Sistema actualizado.${N}"
    pause
}

change_root_pass() {
    echo -e "${Y}Cambiando contraseña de root...${N}"
    passwd root
    pause
}

configure_domain() {
    echo -e "${Y}Configurar dominio (ejemplo: editar /etc/hosts)${N}"
    echo -e "${C}Ingresa el dominio deseado:${N}"
    read -r dominio
    if [[ -n "$dominio" ]]; then
        echo "$(hostname -I | awk '{print $1}') $dominio" >> /etc/hosts
        echo -e "${G}Dominio $dominio agregado a /etc/hosts.${N}"
    fi
    pause
}

# ------------------------------------------------------------------
# 4. Bucle principal del menú
# ------------------------------------------------------------------
while true; do
    clear_screen
    msg -bar
    echo -e "${W}                        HERRAMIENTAS${N}"
    msg -bar
    echo -e " ${R}[${Y}01${R}] ${R}» ${C}LIMPIAR CACHE         ${R}[${Y}05${R}] ${R}» ${C}CAMBIAR PASS ROOT${N}"
    echo -e " ${R}[${Y}02${R}] ${R}» ${C}GESTION SWAP          ${R}[${Y}06${R}] ${R}» ${C}CONFIGURAR DOMINIO${N}"
    echo -e " ${R}[${Y}03${R}] ${R}» ${C}REINICIAR SERVICIOS   ${R}[${Y}07${R}] ${R}» ${C}ZONA HORARIA${N}"
    echo -e " ${R}[${Y}04${R}] ${R}» ${C}ACTUALIZAR SISTEMA    ${R}[${Y}08${R}] ${R}» ${Y}${BOLD}TEMAS DEL PANEL${N}"
    msg -bar3
    echo -e " ${R}[${Y}00${R}] ${R}« SALIR${N}"
    msg -bar
    echo -ne "${W}┌─[${G}${BOLD}Seleccione una opción${W}]${N}\n╰─> : ${G}"
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
      8|08)
        # Ejecuta el selector de temas y recarga colores para aplicar cambios
        run_module "menucolor.sh" "$ROOT_DIR"
        # Recarga la librería completa (puede que haya cambiado el tema)
        if [[ -f "$LIB_COLORES" ]]; then
            source "$LIB_COLORES"
        else
            echo -e "${R}No se pudo recargar colores, se mantiene el fallback.${N}"
        fi
        ;;
      0|00) exit 0 ;;
      *) echo -e "${R} Opción inválida${N}"; sleep 1 ;;
    esac
done
