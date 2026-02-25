#!/usr/bin/env bash
export DEBIAN_FRONTEND=noninteractive
set -e

# Colores de texto
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
RESET='\033[0m'

# Limpiar pantalla
clear

# Barra de progreso
fun_bar () {
  comando="$1"
  (
    [[ -e $HOME/fim ]] && rm $HOME/fim
    $comando > /dev/null 2>&1
    touch $HOME/fim
  ) > /dev/null 2>&1 &

  tput civis
  echo -ne "  ${YELLOW}WAIT ${WHITE}- ${YELLOW}["
  while true; do
    for ((i = 0; i < 18; i++)); do
      echo -ne "${RED}#"
      sleep 0.1
    done
    [[ -e $HOME/fim ]] && rm $HOME/fim && break
    echo -e "${YELLOW}]"
    sleep 1
    tput cuu1
    tput dl1
    echo -ne "  ${YELLOW}WAIT ${WHITE}- ${YELLOW}["
  done
  echo -e "${YELLOW}]${WHITE} -${GREEN} OK !${WHITE}"
  tput cnorm
}

# Título
echo -e "${GRAY}[${RED}-${GRAY}]${RED} ───────────────── /// ────────────────── ${YELLOW}"
command -v figlet >/dev/null 2>&1 || apt install figlet -y > /dev/null
figlet -p -f slant SlowDNS
echo -e "${GRAY}[${RED}-${GRAY}]${RED} ────────────── Installer ─────────────── ${YELLOW}\n"
echo -e "      This script will install SlowDNS connection mode.\n"
echo -e "${GRAY}[${RED}-${GRAY}]${RED} ───────────────── /// ────────────────── ${YELLOW}\n"

echo -e "DOWNLOADING DEPENDENCIES...\n"

apt install ncurses-bin -y > /dev/null 2>&1
mkdir -p /etc/slowdns
cd /etc/slowdns
base_url="https://raw.githubusercontent.com/powermx/dnstt/main"

wget -q https://github.com/powermx/dnstt/raw/main/dns-server -O dns-server && chmod +x dns-server

for file in \
  remove-slow slowdns-info slowdns-drop slowdns-ssh slowdns-ssl \
  slowdns-socks slowdns-customservice stopdns; do
  wget -q "${base_url}/${file}" -O "${file}" && chmod +x "${file}"
done

wget -q "${base_url}/slowdns" -O /bin/slowdns && chmod +x /bin/slowdns

echo -e "\nSETTING CLOUDFLARE DNS...\n"

fun_dnscf () {
  systemctl disable systemd-resolved.service
  systemctl stop systemd-resolved.service
  mv /etc/resolv.conf /etc/resolv.conf.bkp 2>/dev/null || true
  echo "nameserver 1.1.1.1" > /etc/resolv.conf
  systemctl enable systemd-resolved.service
  systemctl start systemd-resolved.service
  sleep 2
}

fun_bar fun_dnscf

# Final
clear
echo -e "${GRAY}[${RED}-${GRAY}]${RED} ───────────────── /// ────────────────── ${YELLOW}"
figlet -p -f slant SlowDNS
echo -e "${GRAY}[${RED}-${GRAY}]${RED} ────────────── Installer ─────────────── ${YELLOW}\n"
echo -e "          ${YELLOW}INSTALLATION COMPLETED${RESET}\n"
echo -e "To open the menu, use the command: ${RED}slowdns${RESET}\n"

cd
sleep 3

# Ejecutar si slowdns fue correctamente instalado
if command -v slowdns >/dev/null 2>&1; then
  slowdns
else
  echo -e "${RED}Error: 'slowdns' command not found.${RESET}"
fi
