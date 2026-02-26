#!/usr/bin/env bash
export DEBIAN_FRONTEND=noninteractive

# ==================================================
# 📌 COLORES OFICIALES SINNOMBRE22
# ==================================================
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; B='\033[0;34m'
M='\033[0;35m'; C='\033[0;36m'; W='\033[1;37m'; N='\033[0m'
BOLD='\033[1m'
ROJO="\e[31m"; BLANCO="\e[97m"; CYAN="\e[36m"; AMARILLO="\e[33m"; RESET="\e[0m"

# ==================================================
# 📌 LÍNEA OFICIAL (NO MODIFICAR)
# ==================================================
LINEA="${ROJO}══════════════════════════ / / / ══════════════════════════${RESET}"

# ==================================================
# 📌 BARRA DE PROGRESO OFICIAL
# ==================================================
barra_progreso() {
    echo -ne "${CYAN}ESPERANDO ${ROJO}["
    for ((i=0;i<18;i++)); do
        echo -ne "#"
        sleep 0.05
    done
    echo -e "] ${G}OK${RESET}"
}

# ==================================================
# 📌 LOGO (NORMAL, NO CENTRADO)
# ==================================================
mostrar_logo() {
    clear
    echo -e "$LINEA"

    LOGO=$(figlet -f slant SlowDNS)
    echo -e "${AMARILLO}${LOGO}${RESET}"

    echo -e "$LINEA"
    echo -e "${BOLD}${BLANCO}                INSTALADOR OFICIAL SINNOMBRE22                ${RESET}"
    echo -e "$LINEA"
}

# ==================================================
# 📌 CONFIGURAR FIREWALL
# ==================================================
configurar_firewall() {
    systemctl enable firewalld >/dev/null 2>&1
    systemctl start firewalld >/dev/null 2>&1

    firewall-cmd --zone=public --permanent --add-port=53/udp >/dev/null 2>&1
    firewall-cmd --zone=public --permanent --add-port=5300/udp >/dev/null 2>&1
    firewall-cmd --reload >/dev/null 2>&1
}

# ==================================================
# 📌 CONFIGURAR DNS
# ==================================================
configurar_dns() {
    echo "nameserver 1.1.1.1" > /etc/resolv.conf
}

# ==================================================
# 📌 INSTALAR SLOWDNS
# ==================================================
instalar_slowdns() {

    echo -e "$LINEA"
    echo -e "${BOLD}${BLANCO}                    INSTALANDO SLOWDNS                    ${RESET}"
    echo -e "$LINEA"

    echo
    barra_progreso

    apt update -y >/dev/null 2>&1
    apt install wget figlet firewalld -y >/dev/null 2>&1

    mkdir -p /etc/slowdns
    cd /etc/slowdns || return

    wget -q https://raw.githubusercontent.com/SINNOMBRE22/dnstt/main/dns-server -O dns-server
    chmod +x dns-server

    configurar_firewall
    configurar_dns

    echo
    echo -e "${G}✔ Proceso completado correctamente${RESET}"
    sleep 2
}

# ==================================================
# 📌 MENÚ PRINCIPAL
# ==================================================
menu() {

    while true; do
        mostrar_logo
        echo

        if command -v dns-server >/dev/null 2>&1; then
            echo -e "${G}1)${CYAN} Reinstalar SlowDNS${RESET}"
            echo -e "${G}0)${CYAN} Salir${RESET}"
        else
            echo -e "${R}✖ SlowDNS no está instalado${RESET}"
            echo
            echo -e "${G}1)${CYAN} Instalar SlowDNS${RESET}"
            echo -e "${G}0)${CYAN} Salir${RESET}"
        fi

        echo
        read -p "Seleccione una opción: " opcion

        case $opcion in
            1) instalar_slowdns ;;
            0) exit ;;
            *) 
                echo -e "${Y}⚠ Opción inválida${RESET}"
                sleep 1
                ;;
        esac
    done
}

# ==================================================
# 📌 EJECUCIÓN
# ==================================================
menu
