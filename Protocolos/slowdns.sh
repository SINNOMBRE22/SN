#!/usr/bin/env bash
export DEBIAN_FRONTEND=noninteractive

# ==================================================
# 📌 COLORES OFICIALES SINNOMBRE22
# ==================================================
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'
CYAN="\e[36m"; ROJO="\e[31m"; BLANCO="\e[97m"
RESET="\e[0m"; BOLD='\033[1m'

LINEA="${ROJO}══════════════════════════ / / / ══════════════════════════${RESET}"

# ==================================================
# 📌 BARRA ORIGINAL (INSTALADOR REAL)
# ==================================================
fun_bar () {
comando[0]="$1"
comando[1]="$2"
(
[[ -e $HOME/fim ]] && rm $HOME/fim
${comando[0]} -y > /dev/null 2>&1
${comando[1]} -y > /dev/null 2>&1
touch $HOME/fim
) > /dev/null 2>&1 &
tput civis
echo -ne "  ${Y}PROCESANDO ${CYAN}["
while true; do
   for((i=0; i<18; i++)); do
   echo -ne "${R}#"
   sleep 0.08s
   done
   [[ -e $HOME/fim ]] && rm $HOME/fim && break
   echo -e "${CYAN}]"
   sleep 1s
   tput cuu1 && tput dl1
   echo -ne "  ${Y}PROCESANDO ${CYAN}["
done
echo -e "${CYAN}] ${G}OK${RESET}"
tput cnorm
}

# ==================================================
# 📌 LOGO
# ==================================================
mostrar_logo() {
    clear
    echo -e "$LINEA"
    figlet -p -f slant SlowDNS
    echo -e "$LINEA"
    echo -e "${BOLD}${BLANCO}                INSTALADOR OFICIAL SINNOMBRE22                ${RESET}"
    echo -e "$LINEA"
}

# ==================================================
# 📌 VERIFICACIÓN
# ==================================================
esta_instalado() {
    [[ -f /etc/slowdns/dns-server ]]
}

# ==================================================
# 📌 INSTALACIÓN ORIGINAL COMPLETA
# ==================================================
instalar_slowdns() {

mostrar_logo
echo
echo -e "${Y}DESCARGANDO DEPENDENCIAS...${RESET}"
echo

fun_att () {

apt update -y
apt install figlet firewalld ncurses-utils wget -y

mkdir -p /etc/slowdns
cd /etc/slowdns || exit

wget https://github.com/SINNOMBRE22/dnstt/raw/main/dns-server -O dns-server
chmod +x dns-server

wget https://raw.githubusercontent.com/SINNOMBRE22/dnstt/main/remove-slow -O remove-slow
chmod +x remove-slow

wget https://raw.githubusercontent.com/SINNOMBRE22/dnstt/main/slowdns-info -O slowdns-info
chmod +x slowdns-info

wget https://raw.githubusercontent.com/SINNOMBRE22/dnstt/main/slowdns-drop -O slowdns-drop
chmod +x slowdns-drop

wget https://raw.githubusercontent.com/SINNOMBRE22/dnstt/main/slowdns-ssh -O slowdns-ssh
chmod +x slowdns-ssh

wget https://raw.githubusercontent.com/SINNOMBRE22/dnstt/main/slowdns-ssl -O slowdns-ssl
chmod +x slowdns-ssl

wget https://raw.githubusercontent.com/SINNOMBRE22/dnstt/main/slowdns-socks -O slowdns-socks
chmod +x slowdns-socks

wget https://raw.githubusercontent.com/SINNOMBRE22/dnstt/main/slowdns-customservice -O slowdns-customservice
chmod +x slowdns-customservice

wget -qO /bin/slowdns https://raw.githubusercontent.com/SINNOMBRE22/dnstt/main/slowdns
chmod +x /bin/slowdns

wget https://raw.githubusercontent.com/SINNOMBRE22/dnstt/main/stopdns -O stopdns
chmod +x stopdns
}

fun_bar 'fun_att'

echo
echo -e "${Y}CONFIGURANDO FIREWALL...${RESET}"
echo

fun_ports () {
systemctl enable firewalld
systemctl start firewalld

firewall-cmd --zone=public --permanent --add-port=80/tcp
firewall-cmd --zone=public --permanent --add-port=8080/tcp
firewall-cmd --zone=public --permanent --add-port=443/tcp
firewall-cmd --zone=public --permanent --add-port=85/tcp
firewall-cmd --zone=public --permanent --add-port=2222/tcp
firewall-cmd --zone=public --permanent --add-port=53/udp
firewall-cmd --zone=public --permanent --add-port=5300/udp
firewall-cmd --reload
}

fun_bar 'fun_ports'

echo
echo -e "${Y}CONFIGURANDO DNS CLOUDFLARE...${RESET}"
echo

fun_dnscf () {
systemctl disable systemd-resolved.service
systemctl stop systemd-resolved.service
rm -f /etc/resolv.conf
echo "nameserver 1.1.1.1" > /etc/resolv.conf
sleep 2
}

fun_bar 'fun_dnscf'

clear
mostrar_logo
echo
echo -e "${G}✔ INSTALACIÓN COMPLETADA CORRECTAMENTE${RESET}"
sleep 2
slowdns
}

# ==================================================
# 📌 MENÚ
# ==================================================
menu() {
while true; do
mostrar_logo
echo

if esta_instalado; then
    echo -e "${G}✔ SlowDNS ya está instalado${RESET}"
    echo
    echo -e "${CYAN}1) Reinstalar SlowDNS${RESET}"
    echo -e "${CYAN}0) Salir${RESET}"
    echo
    read -p "Seleccione una opción: " opcion

    case $opcion in
        1) instalar_slowdns ;;
        0) exit ;;
        *) echo -e "${Y}Opción inválida${RESET}"; sleep 1 ;;
    esac
else
    echo -e "${R}✖ SlowDNS no está instalado${RESET}"
    echo
    echo -e "${CYAN}1) Instalar SlowDNS${RESET}"
    echo -e "${CYAN}0) Salir${RESET}"
    echo
    read -p "Seleccione una opción: " opcion

    case $opcion in
        1) instalar_slowdns ;;
        0) exit ;;
        *) echo -e "${Y}Opción inválida${RESET}"; sleep 1 ;;
    esac
fi

done
}

menu
