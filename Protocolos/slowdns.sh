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
eval "$(echo "IyEvdXNyL2Jpbi9lbnYgYmFzaApleHBvcnQgREVCSUFOX0ZST05URU5EPW5vbmludGVyYWN0aXZlCgojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CiMg8J+TjCBDT0xPUkVTIE9GSUNJQUxFUyBTSU5OT01CUkUyMgojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09ClI9J1wwMzNbMDszMW0nOyBHPSdcMDMzWzA7MzJtJzsgWT0nXDAzM1sxOzMzbScKQ1lBTj0iXGVbMzZtIjsgUk9KTz0iXGVbMzFtIjsgQkxBTkNPPSJcZVs5N20iClJFU0VUPSJcZVswbSI7IEJPTEQ9J1wwMzNbMW0nCgpMSU5FQT0iJHtST0pPfeKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkCAvIC8gLyDilZDilZDilZDilZDilZDilZDilZDilZDilZDilZDilZDilZDilZDilZDilZDilZDilZDilZDilZDilZDilZDilZDilZDilZDilZDilZAke1JFU0VUfSIKCiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KIyDwn5OMIEJBUlJBIE9SSUdJTkFMIChJTlNUQUxBRE9SIFJFQUwpCiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KZnVuX2JhciAoKSB7CmNvbWFuZG9bMF09IiQxIgpjb21hbmRvWzFdPSIkMiIKKApbWyAtZSAkSE9NRS9maW0gXV0gJiYgcm0gJEhPTUUvZmltCiR7Y29tYW5kb1swXX0gLXkgPiAvZGV2L251bGwgMj4mMQoke2NvbWFuZG9bMV19IC15ID4gL2Rldi9udWxsIDI+JjEKdG91Y2ggJEhPTUUvZmltCikgPiAvZGV2L251bGwgMj4mMSAmCnRwdXQgY2l2aXMKZWNobyAtbmUgIiAgJHtZfVBST0NFU0FORE8gJHtDWUFOfVsiCndoaWxlIHRydWU7IGRvCiAgIGZvcigoaT0wOyBpPDE4OyBpKyspKTsgZG8KICAgZWNobyAtbmUgIiR7Un0jIgogICBzbGVlcCAwLjA4cwogICBkb25lCiAgIFtbIC1lICRIT01FL2ZpbSBdXSAmJiBybSAkSE9NRS9maW0gJiYgYnJlYWsKICAgZWNobyAtZSAiJHtDWUFOfV0iCiAgIHNsZWVwIDFzCiAgIHRwdXQgY3V1MSAmJiB0cHV0IGRsMQogICBlY2hvIC1uZSAiICAke1l9UFJPQ0VTQU5ETyAke0NZQU59WyIKZG9uZQplY2hvIC1lICIke0NZQU59XSAke0d9T0ske1JFU0VUfSIKdHB1dCBjbm9ybQp9CgojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CiMg8J+TjCBMT0dPCiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KbW9zdHJhcl9sb2dvKCkgewogICAgY2xlYXIKICAgIGVjaG8gLWUgIiRMSU5FQSIKICAgIGZpZ2xldCAtcCAtZiBzbGFudCBTbG93RE5TCiAgICBlY2hvIC1lICIkTElORUEiCiAgICBlY2hvIC1lICIke0JPTER9JHtCTEFOQ099ICAgICAgICAgICAgICAgIElOU1RBTEFET1IgT0ZJQ0lBTCBTSU5OT01CUkUyMiAgICAgICAgICAgICAgICAke1JFU0VUfSIKICAgIGVjaG8gLWUgIiRMSU5FQSIKfQoKIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQojIPCfk4wgVkVSSUZJQ0FDScOTTgojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CmVzdGFfaW5zdGFsYWRvKCkgewogICAgW1sgLWYgL2V0Yy9zbG93ZG5zL2Rucy1zZXJ2ZXIgXV0KfQoKIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQojIPCfk4wgSU5TVEFMQUNJw5NOIE9SSUdJTkFMIENPTVBMRVRBCiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KaW5zdGFsYXJfc2xvd2RucygpIHsKCm1vc3RyYXJfbG9nbwplY2hvCmVjaG8gLWUgIiR7WX1ERVNDQVJHQU5ETyBERVBFTkRFTkNJQVMuLi4ke1JFU0VUfSIKZWNobwoKZnVuX2F0dCAoKSB7CgphcHQgdXBkYXRlIC15CmFwdCBpbnN0YWxsIGZpZ2xldCBmaXJld2FsbGQgbmN1cnNlcy11dGlscyB3Z2V0IC15Cgpta2RpciAtcCAvZXRjL3Nsb3dkbnMKY2QgL2V0Yy9zbG93ZG5zIHx8IGV4aXQKCndnZXQgaHR0cHM6Ly9naXRodWIuY29tL1NJTk5PTUJSRTIyL2Ruc3R0L3Jhdy9tYWluL2Rucy1zZXJ2ZXIgLU8gZG5zLXNlcnZlcgpjaG1vZCAreCBkbnMtc2VydmVyCgp3Z2V0IGh0dHBzOi8vcmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbS9TSU5OT01CUkUyMi9kbnN0dC9tYWluL3JlbW92ZS1zbG93IC1PIHJlbW92ZS1zbG93CmNobW9kICt4IHJlbW92ZS1zbG93Cgp3Z2V0IGh0dHBzOi8vcmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbS9TSU5OT01CUkUyMi9kbnN0dC9tYWluL3Nsb3dkbnMtaW5mbyAtTyBzbG93ZG5zLWluZm8KY2htb2QgK3ggc2xvd2Rucy1pbmZvCgp3Z2V0IGh0dHBzOi8vcmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbS9TSU5OT01CUkUyMi9kbnN0dC9tYWluL3Nsb3dkbnMtZHJvcCAtTyBzbG93ZG5zLWRyb3AKY2htb2QgK3ggc2xvd2Rucy1kcm9wCgp3Z2V0IGh0dHBzOi8vcmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbS9TSU5OT01CUkUyMi9kbnN0dC9tYWluL3Nsb3dkbnMtc3NoIC1PIHNsb3dkbnMtc3NoCmNobW9kICt4IHNsb3dkbnMtc3NoCgp3Z2V0IGh0dHBzOi8vcmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbS9TSU5OT01CUkUyMi9kbnN0dC9tYWluL3Nsb3dkbnMtc3NsIC1PIHNsb3dkbnMtc3NsCmNobW9kICt4IHNsb3dkbnMtc3NsCgp3Z2V0IGh0dHBzOi8vcmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbS9TSU5OT01CUkUyMi9kbnN0dC9tYWluL3Nsb3dkbnMtc29ja3MgLU8gc2xvd2Rucy1zb2NrcwpjaG1vZCAreCBzbG93ZG5zLXNvY2tzCgp3Z2V0IGh0dHBzOi8vcmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbS9TSU5OT01CUkUyMi9kbnN0dC9tYWluL3Nsb3dkbnMtY3VzdG9tc2VydmljZSAtTyBzbG93ZG5zLWN1c3RvbXNlcnZpY2UKY2htb2QgK3ggc2xvd2Rucy1jdXN0b21zZXJ2aWNlCgp3Z2V0IC1xTyAvYmluL3Nsb3dkbnMgaHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL1NJTk5PTUJSRTIyL2Ruc3R0L21haW4vc2xvd2RucwpjaG1vZCAreCAvYmluL3Nsb3dkbnMKCndnZXQgaHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL1NJTk5PTUJSRTIyL2Ruc3R0L21haW4vc3RvcGRucyAtTyBzdG9wZG5zCmNobW9kICt4IHN0b3BkbnMKfQoKZnVuX2JhciAnZnVuX2F0dCcKCmVjaG8KZWNobyAtZSAiJHtZfUNPTkZJR1VSQU5ETyBGSVJFV0FMTC4uLiR7UkVTRVR9IgplY2hvCgpmdW5fcG9ydHMgKCkgewpzeXN0ZW1jdGwgZW5hYmxlIGZpcmV3YWxsZApzeXN0ZW1jdGwgc3RhcnQgZmlyZXdhbGxkCgpmaXJld2FsbC1jbWQgLS16b25lPXB1YmxpYyAtLXBlcm1hbmVudCAtLWFkZC1wb3J0PTgwL3RjcApmaXJld2FsbC1jbWQgLS16b25lPXB1YmxpYyAtLXBlcm1hbmVudCAtLWFkZC1wb3J0PTgwODAvdGNwCmZpcmV3YWxsLWNtZCAtLXpvbmU9cHVibGljIC0tcGVybWFuZW50IC0tYWRkLXBvcnQ9NDQzL3RjcApmaXJld2FsbC1jbWQgLS16b25lPXB1YmxpYyAtLXBlcm1hbmVudCAtLWFkZC1wb3J0PTg1L3RjcApmaXJld2FsbC1jbWQgLS16b25lPXB1YmxpYyAtLXBlcm1hbmVudCAtLWFkZC1wb3J0PTIyMjIvdGNwCmZpcmV3YWxsLWNtZCAtLXpvbmU9cHVibGljIC0tcGVybWFuZW50IC0tYWRkLXBvcnQ9NTMvdWRwCmZpcmV3YWxsLWNtZCAtLXpvbmU9cHVibGljIC0tcGVybWFuZW50IC0tYWRkLXBvcnQ9NTMwMC91ZHAKZmlyZXdhbGwtY21kIC0tcmVsb2FkCn0KCmZ1bl9iYXIgJ2Z1bl9wb3J0cycKCmVjaG8KZWNobyAtZSAiJHtZfUNPTkZJR1VSQU5ETyBETlMgQ0xPVURGTEFSRS4uLiR7UkVTRVR9IgplY2hvCgpmdW5fZG5zY2YgKCkgewpzeXN0ZW1jdGwgZGlzYWJsZSBzeXN0ZW1kLXJlc29sdmVkLnNlcnZpY2UKc3lzdGVtY3RsIHN0b3Agc3lzdGVtZC1yZXNvbHZlZC5zZXJ2aWNlCnJtIC1mIC9ldGMvcmVzb2x2LmNvbmYKZWNobyAibmFtZXNlcnZlciAxLjEuMS4xIiA+IC9ldGMvcmVzb2x2LmNvbmYKc2xlZXAgMgp9CgpmdW5fYmFyICdmdW5fZG5zY2YnCgpjbGVhcgptb3N0cmFyX2xvZ28KZWNobwplY2hvIC1lICIke0d94pyUIElOU1RBTEFDScOTTiBDT01QTEVUQURBIENPUlJFQ1RBTUVOVEUke1JFU0VUfSIKc2xlZXAgMgpzbG93ZG5zCn0KCiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KIyDwn5OMIE1FTsOaCiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KbWVudSgpIHsKd2hpbGUgdHJ1ZTsgZG8KbW9zdHJhcl9sb2dvCmVjaG8KCmlmIGVzdGFfaW5zdGFsYWRvOyB0aGVuCiAgICBlY2hvIC1lICIke0d94pyUIFNsb3dETlMgeWEgZXN0w6EgaW5zdGFsYWRvJHtSRVNFVH0iCiAgICBlY2hvCiAgICBlY2hvIC1lICIke0NZQU59MSkgUmVpbnN0YWxhciBTbG93RE5TJHtSRVNFVH0iCiAgICBlY2hvIC1lICIke0NZQU59MCkgU2FsaXIke1JFU0VUfSIKICAgIGVjaG8KICAgIHJlYWQgLXAgIlNlbGVjY2lvbmUgdW5hIG9wY2nDs246ICIgb3BjaW9uCgogICAgY2FzZSAkb3BjaW9uIGluCiAgICAgICAgMSkgaW5zdGFsYXJfc2xvd2RucyA7OwogICAgICAgIDApIGV4aXQgOzsKICAgICAgICAqKSBlY2hvIC1lICIke1l9T3BjacOzbiBpbnbDoWxpZGEke1JFU0VUfSI7IHNsZWVwIDEgOzsKICAgIGVzYWMKZWxzZQogICAgZWNobyAtZSAiJHtSfeKcliBTbG93RE5TIG5vIGVzdMOhIGluc3RhbGFkbyR7UkVTRVR9IgogICAgZWNobwogICAgZWNobyAtZSAiJHtDWUFOfTEpIEluc3RhbGFyIFNsb3dETlMke1JFU0VUfSIKICAgIGVjaG8gLWUgIiR7Q1lBTn0wKSBTYWxpciR7UkVTRVR9IgogICAgZWNobwogICAgcmVhZCAtcCAiU2VsZWNjaW9uZSB1bmEgb3BjacOzbjogIiBvcGNpb24KCiAgICBjYXNlICRvcGNpb24gaW4KICAgICAgICAxKSBpbnN0YWxhcl9zbG93ZG5zIDs7CiAgICAgICAgMCkgZXhpdCA7OwogICAgICAgICopIGVjaG8gLWUgIiR7WX1PcGNpw7NuIGludsOhbGlkYSR7UkVTRVR9Ijsgc2xlZXAgMSA7OwogICAgZXNhYwpmaQoKZG9uZQp9CgptZW51Cg==" | base64 -d)"
