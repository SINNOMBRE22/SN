#!/bin/bash

# ================================
#      PSIPHON MANAGER - SinNombre
# ================================

PSI_DIR="/root"
PSI_BIN="$PSI_DIR/psiphond"
SCREEN_NAME="psiserver"
AUTHOR="SinNombre"

# Colores
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
NC="\033[0m"

# Función para verificar dependencias
check_dependencies() {
    if ! command -v screen &> /dev/null; then
        echo -e "${RED}Error: screen no está instalado. Instalando...${NC}"
        apt update -y && apt install screen -y
    fi
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq no está instalado. Instalando...${NC}"
        apt update -y && apt install jq -y
    fi
}

select_protocol() {
    echo -e "${YELLOW}Selecciona el protocolo de Psiphon:${NC}"
    echo "1) FRONTED-MEEK"
    echo "2) FRONTED-MEEK-HTTP"
    echo "3) MARIONETTE"
    echo "4) OSSH"
    echo "5) QUIC"
    echo "6) SSH"
    echo "7) TAPDANCE"
    echo "8) UNFRONTED-MEEK"
    echo "9) UNFRONTED-MEEK-SESSION-TICKET"
    echo "10) UNFRONTED-MEEK-HTTPS"
    read -p "Opción (1-10, default 1): " proto_opt
    case $proto_opt in
        1) PROTOCOL="FRONTED-MEEK" ;;
        2) PROTOCOL="FRONTED-MEEK-HTTP" ;;
        3) PROTOCOL="MARIONETTE" ;;
        4) PROTOCOL="OSSH" ;;
        5) PROTOCOL="QUIC" ;;
        6) PROTOCOL="SSH" ;;
        7) PROTOCOL="TAPDANCE" ;;
        8) PROTOCOL="UNFRONTED-MEEK" ;;
        9) PROTOCOL="UNFRONTED-MEEK-SESSION-TICKET" ;;
        10) PROTOCOL="UNFRONTED-MEEK-HTTPS" ;;
        *) PROTOCOL="FRONTED-MEEK" ;;
    esac
}

select_port() {
    read -p "Ingresa el puerto (default 443): " PORT
    PORT=${PORT:-443}
    if ! [[ $PORT =~ ^[0-9]+$ ]] || [ $PORT -lt 1 ] || [ $PORT -gt 65535 ]; then
        echo -e "${RED}Puerto inválido. Usando 443.${NC}"
        PORT=443
    fi
}

install_psiphon() {
    clear
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}   INSTALANDO PSIPHON - ${AUTHOR}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    check_dependencies
    ufw disable >/dev/null 2>&1
    apt update -y
    apt install screen jq -y

    select_protocol
    select_port

    cd $PSI_DIR || exit
    wget -q https://raw.githubusercontent.com/Psiphon-Labs/psiphon-tunnel-core-binaries/master/psiphond/psiphond
    chmod +x psiphond

    ./psiphond --ipaddress 0.0.0.0 --protocol $PROTOCOL:$PORT generate

    chmod 666 *.config server-entry.dat
    screen -dmS $SCREEN_NAME ./psiphond run

    echo -e "${GREEN}✔ PSIPHON INSTALADO Y EJECUTANDO (Protocolo: $PROTOCOL, Puerto: $PORT)${NC}"
    echo
    cat server-entry.dat
    echo
    read -p "ENTER para continuar..."
}

show_hex() {
    clear
    echo -e "${YELLOW}CÓDIGO PSIPHON (HEX) - ${AUTHOR}${NC}"
    echo
    if [ -f "$PSI_DIR/server-entry.dat" ]; then
        cat $PSI_DIR/server-entry.dat
    else
        echo -e "${RED}Archivo server-entry.dat no encontrado.${NC}"
    fi
    echo
    read -p "ENTER para volver..."
}

show_json() {
    clear
    echo -e "${YELLOW}CÓDIGO PSIPHON (JSON) - ${AUTHOR}${NC}"
    echo
    if [ -f "$PSI_DIR/server-entry.dat" ]; then
        cat $PSI_DIR/server-entry.dat | xxd -p -r | jq .
    else
        echo -e "${RED}Archivo server-entry.dat no encontrado.${NC}"
    fi
    echo
    read -p "ENTER para volver..."
}

restart_psiphon() {
    clear
    if screen -list | grep -q $SCREEN_NAME; then
        screen -X -S $SCREEN_NAME quit
        echo -e "${YELLOW}Reiniciando Psiphon...${NC}"
        screen -dmS $SCREEN_NAME $PSI_BIN run
        echo -e "${GREEN}✔ PSIPHON REINICIADO${NC}"
    else
        echo -e "${RED}Psiphon no está ejecutándose.${NC}"
    fi
    sleep 2
}

check_status() {
    clear
    echo -e "${YELLOW}ESTADO DE PSIPHON - ${AUTHOR}${NC}"
    echo
    if screen -list | grep -q $SCREEN_NAME; then
        echo -e "${GREEN}Psiphon está ejecutándose en screen: $SCREEN_NAME${NC}"
    else
        echo -e "${RED}Psiphon no está ejecutándose.${NC}"
    fi
    echo
    read -p "ENTER para volver..."
}

uninstall_psiphon() {
    clear
    if screen -list | grep -q $SCREEN_NAME; then
        screen -X -S $SCREEN_NAME quit
    fi
    rm -f $PSI_DIR/psiphond*
    rm -f $PSI_DIR/server-entry.dat
    rm -f $PSI_DIR/*.config
    echo -e "${RED}✖ PSIPHON DESINSTALADO${NC}"
    sleep 2
}

menu() {
    clear
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}          MENU PSIPHON - ${AUTHOR}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " ${GREEN}1${NC}) Instalar Psiphon"
    echo -e " ${GREEN}2${NC}) Mostrar código HEX"
    echo -e " ${GREEN}3${NC}) Mostrar código JSON"
    echo -e " ${GREEN}4${NC}) Verificar estado"
    echo -e " ${GREEN}5${NC}) Reiniciar Psiphon"
    echo -e " ${GREEN}6${NC}) Desinstalar Psiphon"
    echo -e " ${GREEN}7${NC}) Salir"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    read -p "Seleccione una opción: " opt
}

while true; do
    menu
    case $opt in
        1) install_psiphon ;;
        2) show_hex ;;
        3) show_json ;;
        4) check_status ;;
        5) restart_psiphon ;;
        6) uninstall_psiphon ;;
        7) exit 0 ;;
        *) echo "Opción inválida"; sleep 1 ;;
    esac
done
