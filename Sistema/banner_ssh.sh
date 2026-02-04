#!/bin/bash
# =========================================================
# SinNombre - Banner SSH Manager (Normal)
# Gestiona banner estático pre-login para SSH
# =========================================================

# Colores
R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
B='\033[0;34m'
M='\033[0;35m'
C='\033[0;36m'
W='\033[1;37m'
N='\033[0m'

# Archivo del banner
BANNER_FILE="/etc/issue.net"

# Función para detectar servicios SSH
detect_ssh_services() {
    ssh_active=false
    dropbear_active=false
    
    if systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null; then
        ssh_active=true
    fi
    
    if systemctl is-active --quiet dropbear 2>/dev/null || pgrep dropbear >/dev/null 2>&1; then
        dropbear_active=true
    fi
}

# Función para aplicar banner
apply_banner() {
    detect_ssh_services
    
    echo -e "${Y}Aplicando banner normal...${N}"
    
    # Para SSH estándar
    if $ssh_active; then
        echo -e "${C}Configurando SSH estándar...${N}"
        
        # Habilitar Banner
        if grep -q "^#Banner" /etc/ssh/sshd_config; then
            sed -i 's/^#Banner.*/Banner \/etc\/issue.net/' /etc/ssh/sshd_config
        elif ! grep -q "^Banner" /etc/ssh/sshd_config; then
            echo "Banner /etc/issue.net" >> /etc/ssh/sshd_config
        fi
        
        echo -e "${G}Reiniciando SSH...${N}"
        systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null
        if [[ $? -eq 0 ]]; then
            echo -e "${G}SSH reiniciado exitosamente.${N}"
        else
            echo -e "${R}Error al reiniciar SSH.${N}"
        fi
    fi
    
    # Para Dropbear
    if $dropbear_active; then
        echo -e "${C}Configurando Dropbear...${N}"
        
        # Actualizar DROPBEAR_EXTRA_ARGS
        if [[ -f /etc/default/dropbear ]]; then
            if grep -q "DROPBEAR_EXTRA_ARGS" /etc/default/dropbear; then
                sed -i 's/DROPBEAR_EXTRA_ARGS=.*/DROPBEAR_EXTRA_ARGS="-b \/etc\/issue.net"/' /etc/default/dropbear
            else
                echo 'DROPBEAR_EXTRA_ARGS="-b /etc/issue.net"' >> /etc/default/dropbear
            fi
        else
            echo 'DROPBEAR_EXTRA_ARGS="-b /etc/issue.net"' > /etc/default/dropbear
        fi
        
        echo -e "${G}Reiniciando Dropbear...${N}"
        service dropbear restart 2>/dev/null
        if [[ $? -eq 0 ]]; then
            echo -e "${G}Dropbear reiniciado exitosamente.${N}"
        else
            echo -e "${R}Error al reiniciar Dropbear.${N}"
        fi
    fi
    
    if ! $ssh_active && ! $dropbear_active; then
        echo -e "${Y}No se detectaron servicios SSH activos.${N}"
        echo -e "${W}Asegúrate de tener SSH o Dropbear instalado.${N}"
    else
        echo -e "${G}Banner activado. Aparecerá en el log del cliente antes de autenticarte.${N}"
    fi
}

# Función para desactivar banner
disable_banner() {
    detect_ssh_services
    
    echo -e "${Y}Desactivando banner...${N}"
    
    # Para SSH estándar
    if $ssh_active; then
        if grep -q "^Banner" /etc/ssh/sshd_config; then
            sed -i 's/^Banner.*/#Banner none/' /etc/ssh/sshd_config
        fi
        systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null
    fi
    
    # Para Dropbear
    if $dropbear_active; then
        if [[ -f /etc/default/dropbear ]] && grep -q "DROPBEAR_EXTRA_ARGS" /etc/default/dropbear; then
            sed -i 's/DROPBEAR_EXTRA_ARGS=.*/DROPBEAR_EXTRA_ARGS=""/' /etc/default/dropbear
        fi
        service dropbear restart 2>/dev/null
    fi
    
    echo -e "${G}Banner desactivado.${N}"
}

# Función para mostrar el menú
show_banner_menu() {
    clear
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${W}              GESTIÓN DE BANNER SSH${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${R}[${Y}1${R}]${N}  ${C}CREAR / EDITAR BANNER${N}"
    echo -e "${R}[${Y}2${R}]${N}  ${C}ELIMINAR BANNER${N}"
    echo -e "${R}[${Y}3${R}]${N}  ${C}VER BANNER ACTUAL${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${R}[${Y}0${R}]${N}  ${C}VOLVER${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo ""
    echo -ne "${W}Selecciona una opción: ${G}"
}

# Función para crear/editar banner
create_edit_banner() {
    clear
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${W}             CREAR / EDITAR BANNER SSH${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${Y}Se abrirá el editor nano para editar el banner.${N}"
    echo -e "${Y}Escribe cualquier texto. Aparecerá antes de pedir contraseña.${N}"
    echo -e "${Y}Guarda con Ctrl+O y sal con Ctrl+X.${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo ""
    read -p "Presiona Enter para continuar..."
    
    touch "$BANNER_FILE"
    nano "$BANNER_FILE"
    
    if [[ -s "$BANNER_FILE" ]]; then
        apply_banner
    else
        disable_banner
    fi
    
    echo ""
    read -p "Presiona Enter para continuar..."
}

# Función para eliminar banner
delete_banner() {
    clear
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${W}               ELIMINAR BANNER SSH${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    
    if [[ ! -f "$BANNER_FILE" ]] || [[ ! -s "$BANNER_FILE" ]]; then
        echo -e "${Y}No hay banner configurado.${N}"
    else
        echo -e "${Y}¿Eliminar banner? (s/n): ${G}"
        read -r confirm
        if [[ "$confirm" =~ ^[sS]$ ]]; then
            rm -f "$BANNER_FILE"
            disable_banner
            echo -e "${G}Banner eliminado.${N}"
        fi
    fi
    
    echo ""
    read -p "Presiona Enter para continuar..."
}

# Función para ver banner actual
view_banner() {
    clear
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${W}               BANNER SSH ACTUAL${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    
    if [[ -f "$BANNER_FILE" ]] && [[ -s "$BANNER_FILE" ]]; then
        echo -e "${C}Contenido del banner:${N}"
        echo -e "${R}────────────────────────── / / / ──────────────────────────${N}"
        cat "$BANNER_FILE"
        echo -e "${R}────────────────────────── / / / ──────────────────────────${N}"
    else
        echo -e "${Y}No hay banner configurado.${N}"
    fi
    
    echo ""
    read -p "Presiona Enter para continuar..."
}

# Función principal del menú
main_banner_menu() {
    while true; do
        show_banner_menu
        read -r option
        
        case "$option" in
            1) create_edit_banner ;;
            2) delete_banner ;;
            3) view_banner ;;
            0) return 0 ;;
            *) 
                clear
                echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
                echo -e "${B}                   OPCIÓN INVÁLIDA${N}"
                echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
                sleep 2
                ;;
        esac
    done
}

# Verificar root
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo -e "${R}Ejecuta como root.${N}"
    exit 1
fi

main_banner_menu
