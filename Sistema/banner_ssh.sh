#!/bin/bash

# =========================================================
# SN Plus - Banner SSH Manager
# Gestiona Banner Estático y Dinámico (Plantillas Limpias)
# =========================================================

# Colores de la terminal
R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
B='\033[0;34m'
M='\033[0;35m'
C='\033[0;36m'
W='\033[1;37m'
N='\033[0m'

# Archivos de configuración
STATIC_BANNER="/etc/issue.net"
DYN_TEMPLATE="/etc/banner_template.txt"
DYN_SCRIPT="/etc/banner_sinnombre.sh"
PAM_SSH="/etc/pam.d/sshd"
PAM_DROPBEAR="/etc/pam.d/dropbear"

# Función del Título del Panel (Figlet + Lolcat)
show_custom_banner() {
    echo -e "${R}══════════════════════════════════════════════════════════${N}"
    if command -v figlet >/dev/null 2>&1 && command -v lolcat >/dev/null 2>&1; then
        figlet -f slant "SN - PLUS" | lolcat
    else
        echo -e "${C}                      SN - PLUS${N}"
    fi
    echo -e "${R}══════════════════════════════════════════════════════════${N}"
}

# Detectar servicios
detect_ssh_services() {
    ssh_active=false; dropbear_active=false
    if systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null; then ssh_active=true; fi  
    if systemctl is-active --quiet dropbear 2>/dev/null || pgrep dropbear >/dev/null 2>&1; then dropbear_active=true; fi
}

# Reiniciar servicios
restart_services() {
    if $ssh_active; then systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null; fi
    if $dropbear_active; then systemctl restart dropbear 2>/dev/null || service dropbear restart 2>/dev/null; fi
}

# ==========================================
# DESACTIVADORES
# ==========================================
disable_static() {
    detect_ssh_services
    if $ssh_active; then sed -i 's/^Banner.*/#Banner none/' /etc/ssh/sshd_config 2>/dev/null; fi
    if $dropbear_active && [[ -f /etc/default/dropbear ]]; then sed -i 's/DROPBEAR_EXTRA_ARGS="-b \/etc\/issue.net"/DROPBEAR_EXTRA_ARGS=""/' /etc/default/dropbear 2>/dev/null; fi
}

disable_dynamic() {
    sed -i '/banner_sinnombre/d' $PAM_SSH 2>/dev/null
    if [[ -f "$PAM_DROPBEAR" ]]; then sed -i '/banner_sinnombre/d' $PAM_DROPBEAR 2>/dev/null; fi
}

# ==========================================
# ACTIVADORES
# ==========================================
enable_static() {
    disable_dynamic 
    detect_ssh_services
    if $ssh_active; then
        if grep -q "^#Banner" /etc/ssh/sshd_config; then sed -i 's/^#Banner.*/Banner \/etc\/issue.net/' /etc/ssh/sshd_config  
        elif ! grep -q "^Banner" /etc/ssh/sshd_config; then echo "Banner /etc/issue.net" >> /etc/ssh/sshd_config; fi
    fi
    if $dropbear_active && [[ -f /etc/default/dropbear ]]; then
        if grep -q "DROPBEAR_EXTRA_ARGS" /etc/default/dropbear; then sed -i 's/DROPBEAR_EXTRA_ARGS=.*/DROPBEAR_EXTRA_ARGS="-b \/etc\/issue.net"/' /etc/default/dropbear  
        else echo 'DROPBEAR_EXTRA_ARGS="-b /etc/issue.net"' >> /etc/default/dropbear; fi
    fi
    restart_services
}

enable_dynamic() {
    disable_static 
    sed -i '2i auth optional pam_exec.so stdout /etc/banner_sinnombre.sh' $PAM_SSH
    if [[ -f "$PAM_DROPBEAR" ]]; then sed -i '2i auth optional pam_exec.so stdout /etc/banner_sinnombre.sh' $PAM_DROPBEAR; fi
    restart_services
}

# ==========================================
# CREADORES / EDITORES
# ==========================================
edit_static() {
    clear
    show_custom_banner
    echo -e "${W}          INSTRUCCIONES PARA BANNER ESTÁTICO${N}"
    echo -e "${R}══════════════════════════════════════════════════════════${N}"
    echo -e "${Y}Se abrirá un editor limpio para tu diseño HTML.${N}"
    echo -e "${C}Nota: Este banner NO soporta mostrar los días restantes.${N}"
    echo -e "${R}══════════════════════════════════════════════════════════${N}"
    read -p "Presiona Enter para abrir el editor..."

    if [[ ! -s "$STATIC_BANNER" ]]; then
        # Texto centrado y con colores tipo arcoíris en HTML
        echo -e '<h1 style="text-align:center"><font color="#FF0033">S</font><font color="#FF9900">N</font> <font color="#FFFF00">P</font><font color="#33FF00">L</font><font color="#00FFFF">U</font><font color="#CC00FF">S</font></h1>' > "$STATIC_BANNER"
    fi
    
    nano "$STATIC_BANNER"
    enable_static
    echo -e "${G}Banner Estático Activado. (Dinámico apagado para evitar conflictos)${N}"
    read -p "Presiona Enter para continuar..."
}

# MOTOR OCULTO PARA EL BANNER DINÁMICO
build_dynamic_engine() {
    cat << 'EOF' > "$DYN_SCRIPT"
#!/bin/bash
if [ "$PAM_USER" != "root" ] && [ -n "$PAM_USER" ]; then
    EXP_DATE=$(LANG=C chage -l "$PAM_USER" | grep "Account expires" | cut -d: -f2 | sed 's/^ *//')
    if [ "$EXP_DATE" == "never" ] || [ -z "$EXP_DATE" ]; then
        EXP="Nunca"; DAYS="Ilimitado"
    else
        EXP_SECONDS=$(date -d "$EXP_DATE" +%s 2>/dev/null)
        TODAY_SECONDS=$(date +%s)
        if [ -z "$EXP_SECONDS" ]; then
            DAYS="Error"; EXP=$EXP_DATE
        else
            DAYS=$(( (EXP_SECONDS - TODAY_SECONDS) / 86400 ))
            if [ "$DAYS" -lt 0 ]; then DAYS=0; fi
            EXP=$(date -d "$EXP_DATE" +"%d/%m/%Y")
        fi
    fi

    # Leemos la plantilla limpia del usuario
    HTML=$(cat /etc/banner_template.txt)
    
    # Reemplazamos las etiquetas por los datos reales
    HTML="${HTML//\[USER\]/$PAM_USER}"
    HTML="${HTML//\[EXP\]/$EXP}"
    HTML="${HTML//\[DAYS\]/$DAYS}"
    
    # Imprimimos el resultado final
    echo -e "\n$HTML"
fi
exit 0
EOF
    chmod +x "$DYN_SCRIPT"
}

edit_dynamic() {
    clear
    show_custom_banner
    echo -e "${W}          INSTRUCCIONES PARA BANNER DINÁMICO${N}"
    echo -e "${R}══════════════════════════════════════════════════════════${N}"
    echo -e "${Y}A continuación se abrirá tu plantilla limpia.${N}"
    echo -e "${C}Usa estas etiquetas exactas en tu diseño HTML:${N}"
    echo -e ""
    echo -e "  ${G}[USER]${N}  -> Nombre del cliente"
    echo -e "  ${G}[EXP]${N}   -> Fecha de expiración"
    echo -e "  ${G}[DAYS]${N}  -> Días restantes"
    echo -e "${R}══════════════════════════════════════════════════════════${N}"
    read -p "Presiona Enter para abrir el editor..."

    if [[ ! -s "$DYN_TEMPLATE" ]]; then
        # Texto centrado y con colores tipo arcoíris en HTML
        cat << 'EOF' > "$DYN_TEMPLATE"
<h1 style="text-align:center"><font color="#FF0033">S</font><font color="#FF9900">N</font> <font color="#FFFF00">P</font><font color="#33FF00">L</font><font color="#00FFFF">U</font><font color="#CC00FF">S</font></h1>
EOF
    fi

    nano "$DYN_TEMPLATE"
    
    build_dynamic_engine
    enable_dynamic
    echo -e "${G}Banner Dinámico Activado. (Estático apagado para evitar conflictos)${N}"
    read -p "Presiona Enter para continuar..."
}

disable_all() {
    disable_static
    disable_dynamic
    restart_services
    echo -e "${Y}Todos los banners han sido desactivados del sistema.${N}"
    read -p "Presiona Enter para continuar..."
}

delete_all() {
    clear
    show_custom_banner
    echo -e "${W}                  ELIMINAR BANNERS${N}"
    echo -e "${R}══════════════════════════════════════════════════════════${N}"
    echo -e "${Y}Esto borrará por completo tus diseños y configuraciones.${N}"
    echo -ne "¿Estás seguro de que deseas continuar? (s/n): "
    read -r confirm
    
    if [[ "$confirm" == "s" || "$confirm" == "S" ]]; then
        echo -e "\n${C}Limpiando sistema...${N}"
        disable_static
        disable_dynamic
        rm -f "$STATIC_BANNER" "$DYN_TEMPLATE" "$DYN_SCRIPT"
        restart_services
        echo -e "${G}¡Banners eliminados correctamente!${N}"
    else
        echo -e "\n${Y}Operación cancelada.${N}"
    fi
    read -p "Presiona Enter para continuar..."
}

# ==========================================
# MENÚ PRINCIPAL
# ==========================================
show_menu() {
    estado_estatico="${R}[OFF]${N}"
    estado_dinamico="${R}[OFF]${N}"
    
    if grep -q "^Banner /etc/issue.net" /etc/ssh/sshd_config 2>/dev/null; then estado_estatico="${G}[ON]${N}"; fi
    if grep -q "banner_sinnombre.sh" $PAM_SSH 2>/dev/null; then estado_dinamico="${G}[ON]${N}"; fi

    clear
    show_custom_banner
    echo -e "${R}[${Y}1${R}]${N}  ${C}BANNER ESTÁTICO${N}      $estado_estatico  (Normal)"
    echo -e "${R}[${Y}2${R}]${N}  ${C}BANNER DINÁMICO${N}      $estado_dinamico  (CheckUser)"
    echo -e "${R}[${Y}3${R}]${N}  ${C}DESACTIVAR AMBOS${N}     (Apagar banners)"
    echo -e "${R}[${Y}4${R}]${N}  ${C}ELIMINAR BANNERS${N}     (Borrar archivos)"
    echo -e "${R}══════════════════════════════════════════════════════════${N}"
    echo -e "${R}[${Y}0${R}]${N}  ${C}VOLVER AL MENÚ PRINCIPAL${N}"
    echo -e "${R}══════════════════════════════════════════════════════════${N}"
    echo -ne "${W}Selecciona una opción: ${G}"
}

main_menu() {
    while true; do
        show_menu
        read -r option
        case "$option" in  
            1) edit_static ;;  
            2) edit_dynamic ;;  
            3) disable_all ;;  
            4) delete_all ;;
            0) return 0 ;;  
            *) echo -e "${R}Opción inválida.${N}"; sleep 1 ;;  
        esac  
    done
}

# Verificar root
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo -e "${R}Ejecuta como root.${N}"
    exit 1
fi

main_menu
