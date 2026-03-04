#!/bin/bash

# Colores y Formato
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' 

linea_roja="${RED}══════════════════════════ / / / ══════════════════════════${NC}"

clear
echo -e "$linea_roja"
echo -e "${CYAN}          S I N  N O M B R E  -  P A Y L O A D  M A K E R${NC}"
echo -e "$linea_roja"

# 1. Datos de entrada
read -p "$(echo -e ${YELLOW}"[+] Ingresa el Host/Bug (ej. m.facebook.com): "${NC})" host
read -p "$(echo -e ${YELLOW}"[+] Método (GET, POST, CONNECT, HEAD): "${NC})" metodo
metodo=${metodo:-GET} # GET por defecto

echo -e "\n${CYAN}[!] Generando Payload...${NC}"

# 2. Estructura del Payload (Estilo HTTP Custom)
# [method] [host_port] [protocol]\r\nHost: [host]\r\nConnection: Keep-Alive\r\n\r\n
payload="${metodo} / HTTP/1.1\r\nHost: ${host}\r\nConnection: Keep-Alive\r\nUser-Agent: Chrome/110.0.0.0\r\n\r\n"

echo -e "$linea_roja"
echo -e "${GREEN}PAYLOAD GENERADO:${NC}"
echo -e "${YELLOW}${payload}${NC}"
echo -e "$linea_roja"

# 3. Test de Inyección Real
echo -e "${CYAN}[?] ¿Deseas probar este payload contra el host? (s/n):${NC} "
read test_opt

if [[ "$test_opt" == "s" || "$test_opt" == "S" ]]; then
    echo -e "${CYAN}Enviando petición...${NC}\n"
    # Usamos printf para interpretar los \r\n correctamente y enviarlos vía curl
    printf "$payload" | curl -v -X $metodo -s -o /dev/null --connect-timeout 5 "$host" 2>&1 | grep -E "< HTTP/|< Location:|< Server:"
else
    echo -e "${RED}Operación cancelada.${NC}"
fi

echo -e "\n$linea_roja"
