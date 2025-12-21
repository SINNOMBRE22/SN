#!/bin/bash
set -euo pipefail

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

pause() { echo ""; read -r -p "Presiona Enter para continuar..."; }

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo -e "${R}✗ Ejecuta como root.${N}"
    exit 1
  fi
}

hr() { echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"; }

show_header() {
    clear
    hr
    echo -e "${W}               ADMINISTRADOR DROPBEAR - SinNombre${N}"
    hr
}

is_installed() { 
    command -v dropbear >/dev/null 2>&1 || [[ -f /usr/sbin/dropbear ]]
}

is_on() {
    systemctl is-active --quiet dropbear 2>/dev/null || pgrep -x dropbear >/dev/null 2>&1
}

badge() {
    if is_on; then
        echo -e "${G}● ACTIVO${N}"
    else
        echo -e "${R}○ INACTIVO${N}"
    fi
}

get_ports() {
    local ports=""
    
    if command -v ss >/dev/null 2>&1; then
        ports=$(ss -H -lntp 2>/dev/null | awk '/dropbear/ {print $4}' | awk -F: '{print $NF}' | sort -nu | tr '\n' ',' | sed 's/,$//')
    elif command -v netstat >/dev/null 2>&1; then
        ports=$(netstat -tlpn 2>/dev/null | awk '/dropbear/ {print $4}' | awk -F: '{print $NF}' | sort -nu | tr '\n' ',' | sed 's/,$//')
    fi
    
    if [[ -z "$ports" ]] && [[ -f "$DROPBEAR_CONF" ]]; then
        ports=$(grep -oP 'DROPBEAR_PORT=\K[0-9]+' "$DROPBEAR_CONF" 2>/dev/null || echo "22")
    fi
    
    [[ -n "${ports//,/}" ]] && echo "$ports" || echo "22"
}

change_banner_version() {
    echo -e "${Y}Cambiando banner de Dropbear...${N}"
    
    if [[ ! -f "$DROPBEAR_BIN" ]]; then
        echo -e "${R}✗ Binario de Dropbear no encontrado${N}"
        return 1
    fi
    
    # Crear backup del binario original
    cp "$DROPBEAR_BIN" "${DROPBEAR_BIN}.backup"
    
    # Cambiar la versión en el binario (banner SSH)
    if strings "$DROPBEAR_BIN" | grep -q "SSH-2.0-dropbear"; then
        # Reemplazar la cadena en el binario
        sed -i 's/SSH-2.0-dropbear/SSH-2.0-Mod-SinNombre-dropbear/g' "$DROPBEAR_BIN" 2>/dev/null
        
        # Verificar el cambio
        if strings "$DROPBEAR_BIN" | grep -q "SSH-2.0-Mod-SinNombre-dropbear"; then
            echo -e "${G}✓ Banner cambiado a: SSH-2.0-Mod-SinNombre-dropbear${N}"
            
            # Reforzar permisos
            chmod 755 "$DROPBEAR_BIN"
            
            # Verificar integridad
            if ! dropbear -h 2>&1 | head -1 | grep -q "dropbear"; then
                echo -e "${Y}⚠ Restaurando backup (binario corrupto)${N}"
                mv "${DROPBEAR_BIN}.backup" "$DROPBEAR_BIN"
                chmod 755 "$DROPBEAR_BIN"
                return 1
            fi
            
            return 0
        else
            echo -e "${R}✗ No se pudo cambiar el banner${N}"
            mv "${DROPBEAR_BIN}.backup" "$DROPBEAR_BIN"
            return 1
        fi
    else
        echo -e "${Y}⚠ Banner no encontrado en el binario${N}"
        return 0
    fi
}

install_dropbear() {
    show_header
    echo -e "${W}                 INSTALAR DROPBEAR${N}"
    hr

    if is_installed; then
        echo -e "${Y}✓ Dropbear ya está instalado${N}"
        pause
        return
    fi

    echo -e "${Y}Actualizando repositorios...${N}"
    apt-get update -y >/dev/null 2>&1 || true
    
    echo -e "${Y}Instalando Dropbear...${N}"
    if apt-get install -y dropbear >/dev/null 2>&1; then
        echo -e "${G}✓ Dropbear instalado correctamente${N}"
    else
        echo -e "${R}✗ Error en instalación${N}"
        pause
        return
    fi

    mkdir -p /etc/dropbear 2>/dev/null || true
    
    if [[ ! -f "$DROPBEAR_CONF" ]]; then
        touch "$DROPBEAR_CONF"
        chmod 644 "$DROPBEAR_CONF"
    fi

    cat > "$DROPBEAR_CONF" << EOF
# Configuración Dropbear - SinNombre SSH
NO_START=0
DROPBEAR_PORT=22
DROPBEAR_EXTRA_ARGS="-p 22 -K 300 -t 600"
DROPBEAR_BANNER=""
EOF

    if [[ ! -f /etc/dropbear/dropbear_rsa_host_key ]]; then
        echo -e "${Y}Generando claves RSA...${N}"
        dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key -s 2048 >/dev/null 2>&1
    fi

    # Cambiar banner a versión personalizada
    change_banner_version

    systemctl enable dropbear >/dev/null 2>&1
    systemctl restart dropbear >/dev/null 2>&1

    sleep 2
    
    echo -e "\n${G}✓ Dropbear instalado y configurado${N}"
    echo -e "${Y}Banner personalizado: SSH-2.0-Mod-SinNombre-dropbear${N}"
    
    echo -e "\n${Y}⚠ NOTA IMPORTANTE:${N}"
    echo -e "${W}Para crear usuarios SSH usa el módulo:${N}"
    echo -e "${C}SN/Usuarios/generador.sh${N}"
    
    pause
}

set_port() {
    show_header
    echo -e "${W}              CONFIGURAR PUERTO DROPBEAR${N}"
    hr
    
    local current_ports=$(get_ports)
    echo -e "${Y}Puerto(s) actual(es): ${C}$current_ports${N}"
    echo ""
    
    while true; do
        read -r -p "Nuevo puerto (1-65535): " new_port
        
        if [[ ! "$new_port" =~ ^[0-9]+$ ]]; then
            echo -e "${R}✗ Solo números permitidos${N}"
            continue
        fi
        
        if (( new_port < 1 || new_port > 65535 )); then
            echo -e "${R}✗ Puerto fuera de rango${N}"
            continue
        fi
        
        if ss -lnt 2>/dev/null | grep -q ":$new_port "; then
            echo -e "${Y}⚠ Puerto $new_port ya en uso${N}"
            read -r -p "¿Continuar de todos modos? (s/n): " force
            [[ "${force,,}" != "s" ]] && continue
        fi
        
        break
    done

    if [[ -f "$DROPBEAR_CONF" ]]; then
        sed -i '/^DROPBEAR_PORT=/d' "$DROPBEAR_CONF"
        sed -i '/DROPBEAR_EXTRA_ARGS.*-p/d' "$DROPBEAR_CONF"
        
        echo "DROPBEAR_PORT=$new_port" >> "$DROPBEAR_CONF"
        
        if grep -q "DROPBEAR_EXTRA_ARGS" "$DROPBEAR_CONF"; then
            sed -i "s/DROPBEAR_EXTRA_ARGS=\"/DROPBEAR_EXTRA_ARGS=\"-p $new_port /" "$DROPBEAR_CONF"
        fi
    fi

    systemctl restart dropbear >/dev/null 2>&1
    
    echo -e "\n${G}✓ Puerto configurado a: $new_port${N}"
    
    pause
}

toggle_service() {
    if ! is_installed; then
        echo -e "${R}✗ Dropbear no instalado${N}"
        pause
        return
    fi

    if is_on; then
        echo -e "${Y}Deteniendo Dropbear...${N}"
        systemctl stop dropbear >/dev/null 2>&1
        systemctl disable dropbear >/dev/null 2>&1
        
        echo -e "${G}✓ Dropbear detenido${N}"
    else
        echo -e "${Y}Iniciando Dropbear...${N}"
        systemctl enable dropbear >/dev/null 2>&1
        systemctl start dropbear >/dev/null 2>&1
        
        echo -e "${G}✓ Dropbear iniciado${N}"
    fi
    pause
}

restart_service() {
    if ! is_installed; then
        echo -e "${R}✗ Dropbear no instalado${N}"
        pause
        return
    fi
    
    echo -e "${Y}Reiniciando Dropbear...${N}"
    systemctl restart dropbear >/dev/null 2>&1
    
    echo -e "${G}✓ Servicio reiniciado${N}"
    pause
}

show_status() {
    show_header
    echo -e "${W}                ESTADO DEL SERVICIO${N}"
    hr
    
    echo -e "${W}Instalación:${N}"
    if is_installed; then
        echo -e "  ${G}✓ Instalado${N}"
        # Verificar banner personalizado
        if strings "$DROPBEAR_BIN" 2>/dev/null | grep -q "SSH-2.0-Mod-SinNombre-dropbear"; then
            echo -e "  ${W}Banner:${N} ${C}Personalizado (Mod-SinNombre)${N}"
        else
            echo -e "  ${W}Banner:${N} ${Y}Predeterminado${N}"
        fi
    else
        echo -e "  ${R}✗ No instalado${N}"
    fi
    
    echo -e "\n${W}Servicio:${N}"
    if is_on; then
        echo -e "  ${G}✓ Activo${N}"
        local ports=$(get_ports)
        echo -e "  ${W}Puertos:${N} ${C}$ports${N}"
    else
        echo -e "  ${R}✗ Inactivo${N}"
    fi
    
    echo -e "\n${W}Configuración:${N}"
    if [[ -f "$DROPBEAR_CONF" ]]; then
        echo -e "  ${G}✓ Archivo de configuración encontrado${N}"
    fi
    
    pause
}

update_banner() {
    show_header
    echo -e "${W}          ACTUALIZAR BANNER DROPBEAR${N}"
    hr
    
    if ! is_installed; then
        echo -e "${R}✗ Dropbear no instalado${N}"
        pause
        return
    fi
    
    echo -e "${Y}Banner actual en binario:${N}"
    strings "$DROPBEAR_BIN" 2>/dev/null | grep "SSH-2.0-" | head -1 || echo "No encontrado"
    echo ""
    
    echo -e "${Y}¿Cambiar banner a 'SSH-2.0-Mod-SinNombre-dropbear'?${N}"
    read -r -p "(s/n): " confirm
    
    if [[ "${confirm,,}" == "s" ]]; then
        if change_banner_version; then
            echo -e "\n${G}✓ Banner actualizado${N}"
            echo -e "${Y}Reiniciando servicio...${N}"
            systemctl restart dropbear >/dev/null 2>&1
        fi
    else
        echo -e "${Y}Cancelado${N}"
    fi
    
    pause
}

uninstall_dropbear() {
    show_header
    echo -e "${R}               DESINSTALAR DROPBEAR${N}"
    hr
    
    echo -e "${Y}Advertencia:${N} Esto eliminará Dropbear completamente."
    echo ""
    
    if ! is_installed; then
        echo -e "${Y}Dropbear no está instalado.${N}"
        pause
        return
    fi
    
    read -r -p "¿Estás seguro? (Y/N): " confirm
    
    if [[ "${confirm,,}" != "y" ]]; then
        echo -e "${G}Desinstalación cancelada.${N}"
        pause
        return
    fi
    
    echo -e "\n${Y}Iniciando desinstalación...${N}"
    
    systemctl stop dropbear 2>/dev/null || true
    systemctl disable dropbear 2>/dev/null || true
    
    apt-get purge -y dropbear* >/dev/null 2>&1 || true
    apt-get autoremove -y >/dev/null 2>&1 || true
    
    rm -rf /etc/dropbear 2>/dev/null || true
    rm -f /etc/default/dropbear* 2>/dev/null || true
    
    echo -e "${G}✓ Dropbear eliminado completamente${N}"
    pause
}

diagnose_connection() {
    show_header
    echo -e "${W}          DIAGNÓSTICO DE CONEXIÓN${N}"
    hr
    
    local issues=0
    
    echo -e "${Y}=== 1. Verificación de instalación ===${N}"
    if is_installed; then
        echo -e "  ${G}✓ Dropbear instalado${N}"
        # Verificar banner
        if strings "$DROPBEAR_BIN" 2>/dev/null | grep -q "SSH-2.0-Mod-SinNombre-dropbear"; then
            echo -e "  ${G}✓ Banner personalizado activo${N}"
        else
            echo -e "  ${Y}⚠ Banner predeterminado${N}"
        fi
    else
        echo -e "  ${R}✗ Dropbear NO instalado${N}"
        ((issues++))
    fi
    
    echo -e "\n${Y}=== 2. Estado del servicio ===${N}"
    if is_on; then
        echo -e "  ${G}✓ Servicio activo${N}"
    else
        echo -e "  ${R}✗ Servicio INACTIVO${N}"
        ((issues++))
    fi
    
    echo -e "\n${Y}=== 3. Puertos en escucha ===${N}"
    local ports=$(get_ports)
    echo -e "  ${W}Puertos configurados:${N} ${C}$ports${N}"
    
    for port in ${ports//,/ }; do
        if timeout 1 bash -c "echo > /dev/tcp/127.0.0.1/$port" 2>/dev/null; then
            echo -e "    ${G}✓ Puerto $port escuchando${N}"
        else
            echo -e "    ${R}✗ Puerto $port NO responde${N}"
            ((issues++))
        fi
    done
    
    echo -e "\n${Y}=== 4. Verificación de firewalls ===${N}"
    if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "active"; then
        echo -e "  ${Y}⚠ UFW activo${N}"
        for port in ${ports//,/ }; do
            if ufw status | grep -q "$port"; then
                echo -e "    ${G}✓ Puerto $port permitido en UFW${N}"
            else
                echo -e "    ${R}✗ Puerto $port BLOQUEADO por UFW${N}"
                ((issues++))
            fi
        done
    fi
    
    echo -e "\n${Y}=== 5. Información importante ===${N}"
    echo -e "  ${W}Para problemas de autenticación:${N}"
    echo -e "  ${C}Usa el módulo de usuarios: SN/Usuarios/generador.sh${N}"
    
    echo -e "\n${Y}═══════════════════════════════════════════${N}"
    if [[ $issues -eq 0 ]]; then
        echo -e "${G}       ✓ DIAGNÓSTICO SIN PROBLEMAS       ${N}"
    else
        echo -e "${R}       ⚠ SE DETECTARON $issues PROBLEMAS       ${N}"
    fi
    echo -e "${Y}═══════════════════════════════════════════${N}"
    
    pause
}

main_menu() {
    require_root
    
    while true; do
        show_header
        
        local ports=$(get_ports)
        
        echo -e "${W}Estado actual:${N} $(badge)"
        echo -e "${W}Puerto(s):${N} ${Y}$ports${N}"
        hr
        
        echo -e "${R}[${Y}1${R}]${N} ${C}Instalar Dropbear${N}"
        echo -e "${R}[${Y}2${R}]${N} ${C}Configurar puerto${N}"
        echo -e "${R}[${Y}3${R}]${N} ${C}Iniciar/Detener servicio${N}"
        echo -e "${R}[${Y}4${R}]${N} ${C}Reiniciar servicio${N}"
        echo -e "${R}[${Y}5${R}]${N} ${C}Ver estado completo${N}"
        echo -e "${R}[${Y}6${R}]${N} ${C}Diagnóstico de conexión${N}"
        echo -e "${R}[${Y}7${R}]${N} ${C}Actualizar banner Dropbear${N}"
        echo -e "${R}[${Y}8${R}]${N} ${R}Desinstalar Dropbear${N}"
        echo -e "${R}[${Y}0${R}]${N} ${W}Salir${N}"
        
        hr
        echo ""
        echo -ne "${W}Selecciona una opción [0-8]: ${G}"
        read -r op
        
        case "${op:-}" in
            1) install_dropbear ;;
            2) set_port ;;
            3) toggle_service ;;
            4) restart_service ;;
            5) show_status ;;
            6) diagnose_connection ;;
            7) update_banner ;;
            8) uninstall_dropbear ;;
            0) 
                echo -e "\n${Y}Saliendo...${N}"
                exit 0
                ;;
            *) 
                echo -e "${R}Opción inválida${N}"
                sleep 1
                ;;
        esac
    done
}

# Manejar argumentos de línea de comandos
case "${1:-}" in
    "--status"|"-s")
        require_root
        show_status
        ;;
    "--diagnose"|"-d")
        require_root
        diagnose_connection
        ;;
    "--install"|"-i")
        require_root
        install_dropbear
        ;;
    "--update-banner"|"-b")
        require_root
        update_banner
        ;;
    *)
        main_menu
        ;;
esac
