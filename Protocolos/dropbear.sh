#!/bin/bash
# set -euo pipefail  # REMOVIDO - Causa cierres inesperados

# =========================================================
# SinNombre v1.5 - ADMINISTRADOR DROPBEAR (Actualizado 2024)
# Archivo: SN/Protocolos/dropbear.sh
# =========================================================

R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
B='\033[0;34m'
M='\033[0;35m'
C='\033[0;36m'
W='\033[1;37m'
N='\033[0m'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DROPBEAR_CONF="/etc/default/dropbear"
DROPBEAR_BIN="/usr/sbin/dropbear"

# Función pause mejorada
pause() { 
    echo ""
    echo -ne "${W}Presiona Enter para continuar...${N}"
    read -r -t 30 || true
    echo ""
}

require_root() {
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        echo -e "${R}✗ Ejecuta como root.${N}"
        exit 1
    fi
}

hr() { echo -e "${R}═════════════════════════════════════════════════════════════${N}"; }

show_header() {
    clear
    hr
    echo -e "${W} ADMINISTRADOR DROPBEAR - SinNombre${N}"
    hr
}

is_installed() {
    command -v dropbear >/dev/null 2>&1 || [[ -f "$DROPBEAR_BIN" ]]
}

get_ports() {
    local ports=""
    ports=$(ss -H -lntp 2>/dev/null | awk '/dropbear/ {print $4}' | awk -F: '{print $NF}' | sort -nu | tr '\n' ',' | sed 's/,$//') || true
    if [[ -z "$ports" ]] && [[ -f "$DROPBEAR_CONF" ]]; then
        ports=$(grep -oP 'DROPBEAR_PORT=\K[0-9]+' "$DROPBEAR_CONF" 2>/dev/null || echo "22")
    fi
    [[ -n "${ports//,/}" ]] && echo "$ports" || echo ""
}

show_log() {
    echo -e "${Y}LOG DE DROPBEAR:${N}"
    journalctl -u dropbear --no-pager 2>/dev/null | tail -n 15 || echo -e "${Y}[SN] SSH-2.0-Mod-SinNombre-dropbear_2020.81${N}"
    pause
}

install_dropbear_custom() {
    show_header
    echo -e "${W}         INSTALAR DROPBEAR${N}"
    hr

    if is_installed; then
        echo -e "${Y}Dropbear ya está instalado.${N}"
        pause
        return 0
    fi

    local port=""
    while [[ -z "$port" ]]; do
        read -r -p "Ingresa el puerto para Dropbear [1-65535]: " port
        [[ "$port" =~ ^[0-9]+$ ]] && ((port>=1 && port<=65535)) || port=""
        [[ -z "$port" ]] && echo -e "${R}Puerto inválido.${N}"
    done

    echo -e "${Y}Instalando Dropbear...${N}"
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y dropbear >/dev/null 2>&1 || {
        echo -e "${R}✗ Error al instalar dropbear${N}"
        pause
        return 1
    }

    mkdir -p /etc/dropbear 2>/dev/null || true

    cat > "$DROPBEAR_CONF" << EOF
# Configuración Dropbear - SinNombre SSH
NO_START=0
DROPBEAR_PORT=$port
DROPBEAR_EXTRA_ARGS="-p $port -K 300 -t 600"
DROPBEAR_BANNER=""
EOF

    if [[ ! -f /etc/dropbear/dropbear_rsa_host_key ]]; then
        echo -e "${Y}Generando claves RSA...${N}"
        dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key -s 2048 >/dev/null 2>&1 || {
            echo -e "${Y}Generando claves alternativas...${N}"
            ssh-keygen -t rsa -f /etc/dropbear/dropbear_rsa_host_key -N '' >/dev/null 2>&1 || true
        }
    fi

    systemctl enable dropbear >/dev/null 2>&1 || true
    systemctl restart dropbear >/dev/null 2>&1 || {
        echo -e "${Y}Iniciando dropbear manualmente...${N}"
        pkill dropbear 2>/dev/null || true
        dropbear -p $port -R -E >/dev/null 2>&1 &
    }

    sleep 2
    echo -e "${G}✓ Dropbear instalado y configurado en puerto $port.${N}"
    echo -e "${Y}SSH-2.0-Mod-SinNombre-dropbear_2020.81 activo (LOG/MENSAJE).${N}"
    pause
    return 0
}

set_port_custom() {
    show_header
    hr
    local current_ports
    current_ports=$(get_ports)
    echo -e "${W}Puertos actuales:${N} ${Y}${current_ports:-Ninguno}${N}"
    local new_port=""
    while [[ -z "$new_port" ]]; do
        read -r -p "Ingresa el nuevo puerto [1-65535]: " new_port
        [[ "$new_port" =~ ^[0-9]+$ ]] && ((new_port>=1 && new_port<=65535)) || new_port=""
        [[ -z "$new_port" ]] && echo -e "${R}Puerto inválido.${N}"
    done
    
    # Detener servicio actual
    pkill dropbear 2>/dev/null || true
    systemctl stop dropbear 2>/dev/null || true
    
    # Actualizar configuración
    cat > "$DROPBEAR_CONF" << EOF
# Configuración Dropbear - SinNombre SSH
NO_START=0
DROPBEAR_PORT=$new_port
DROPBEAR_EXTRA_ARGS="-p $new_port -K 300 -t 600"
DROPBEAR_BANNER=""
EOF
    
    # Reiniciar servicio
    systemctl restart dropbear >/dev/null 2>&1 || {
        dropbear -p $new_port -R -E >/dev/null 2>&1 &
    }
    
    echo -e "${G}✓ Puerto configurado a: $new_port${N}"
    pause
    return 0
}

restart_service() {
    show_header
    echo -e "${Y}Reiniciando Dropbear...${N}"
    pkill dropbear 2>/dev/null || true
    systemctl restart dropbear >/dev/null 2>&1 || {
        dropbear -R -E >/dev/null 2>&1 &
    }
    echo -e "${G}✓ Servicio reiniciado${N}"
    pause
    return 0
}

uninstall_dropbear_custom() {
    show_header
    echo -e "${R}DESINSTALAR DROPBEAR${N}"
    hr
    if ! is_installed; then
        echo -e "${Y}Dropbear no está instalado.${N}"
        pause
        return 0
    fi
    read -r -p "¿Desea eliminar Dropbear completamente? (s/n): " confirm
    if [[ "${confirm,,}" == "s" ]]; then
        echo -e "${Y}Eliminando...${N}"
        pkill dropbear 2>/dev/null || true
        systemctl stop dropbear 2>/dev/null || true
        systemctl disable dropbear 2>/dev/null || true
        apt-get purge -y dropbear* >/dev/null 2>&1 || true
        apt-get autoremove -y >/dev/null 2>&1 || true
        rm -rf /etc/dropbear 2>/dev/null || true
        rm -f /etc/default/dropbear* 2>/dev/null || true
        echo -e "${G}✓ Dropbear fue eliminado completamente.${N}"
    else
        echo -e "${G}Eliminación cancelada.${N}"
    fi
    pause
    return 0
}

list_ports_menu() {
    show_header
    hr
    local ports
    ports=$(get_ports)
    if [[ -z "$ports" ]]; then
        echo -e "${Y}No hay puertos Dropbear activos.${N}"
        echo -e "${Y}Verificando procesos...${N}"
        pgrep dropbear && echo -e "${G}Dropbear está corriendo en segundo plano${N}" || echo -e "${R}Dropbear no está corriendo${N}"
    else
        local arr_ports
        IFS=',' read -ra arr_ports <<<"$ports"
        echo -e "${W}Puertos usados Dropbear:${N}"
        local i=1
        for port in "${arr_ports[@]}"; do
            echo -e "${R}[${Y}$i${R}]${N} ${G}$port${N}"
            ((i++))
        done
    fi
    pause
    return 0
}

main_menu() {
    require_root
    while true; do
        show_header
        local ports
        ports=$(get_ports)
        if ! is_installed; then
            echo -e "${Y}Dropbear NO está instalado.${N}"
            hr
            echo -e "${R}[${Y}1${R}]${N} ${C}Instalar Dropbear${N}"
            echo -e "${R}[${Y}0${R}]${N} ${W}Volver/Salir${N}"
            hr
            echo -ne "${W}Selecciona una opción [0-1]: ${G}"
            read -r opt
            case "${opt:-}" in
                1) install_dropbear_custom ;;
                0) exit 0 ;;
                *) echo -e "${R}Opción inválida${N}"; sleep 1 ;;
            esac
            continue
        fi

        echo -e "${W}Estado:${N} ${G}INSTALADO${N} | Puerto(s): ${Y}${ports:-22}${N}"
        hr
        echo -e "${R}[${Y}1${R}]${N} ${C}Reiniciar servicio${N}"
        echo -e "${R}[${Y}2${R}]${N} ${C}Configurar puerto${N}"
        echo -e "${R}[${Y}3${R}]${N} ${C}Ver puertos usados${N}"
        echo -e "${R}[${Y}4${R}]${N} ${C}Ver logs${N}"
        echo -e "${R}[${Y}5${R}]${N} ${R}Eliminar Dropbear${N}"
        echo -e "${R}[${Y}0${R}]${N} ${W}Salir${N}"
        hr
        echo -ne "${W}Selecciona una opción [0-5]: ${G}"
        read -r opt
        case "${opt:-}" in
            1) restart_service ;;
            2) set_port_custom ;;
            3) list_ports_menu ;;
            4) show_log ;;
            5) uninstall_dropbear_custom ;;
            0) exit 0 ;;
            *) echo -e "${R}Opción inválida${N}"; sleep 1 ;;
        esac
    done
}

# Manejo seguro de señales
trap '' SIGINT SIGTERM

case "${1:-}" in
    "--install"|"-i")
        require_root
        install_dropbear_custom
        ;;
    "--set-port"|"-p")
        require_root
        set_port_custom
        ;;
    "--restart"|"-r")
        require_root
        restart_service
        ;;
    "--uninstall"|"-u")
        require_root
        uninstall_dropbear_custom
        ;;
    "--ports"|"-pt")
        require_root
        list_ports_menu
        ;;
    "--log"|"-l")
        require_root
        show_log
        ;;
    *)
        main_menu
        ;;
esac
