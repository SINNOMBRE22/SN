#!/usr/bin/env bash
export DEBIAN_FRONTEND=noninteractive
set -e

# ═══════════════════════════════
# COLORES
# ═══════════════════════════════
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
RESET='\033[0m'

clear

# ═══════════════════════════════
# VERIFICAR ROOT
# ═══════════════════════════════
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Este script debe ejecutarse como root.${RESET}"
   exit 1
fi

# ═══════════════════════════════
# SI YA ESTÁ INSTALADO → ABRIR
# ═══════════════════════════════
if command -v slowdns >/dev/null 2>&1; then
#    echo -e "${GREEN}SlowDNS ya está instalado.${RESET}"
    sleep 1
    slowdns
    exit 0
fi

# ═══════════════════════════════
# INSTALACIÓN
# ═══════════════════════════════
echo -e "${GRAY}[${RED}-${GRAY}]${RED} ───────────────── /// ────────────────── ${YELLOW}"
command -v figlet >/dev/null 2>&1 || apt install figlet -y > /dev/null 2>&1
figlet -p -f slant SlowDNS
echo -e "${GRAY}[${RED}-${GRAY}]${RED} ────────────── Installer ─────────────── ${YELLOW}\n"

echo -e "${YELLOW}SlowDNS no está instalado. Instalando...${RESET}\n"
sleep 2

# Dependencias básicas
apt update -y > /dev/null 2>&1
apt install wget ncurses-bin -y > /dev/null 2>&1

# Crear directorio
mkdir -p /etc/slowdns
cd /etc/slowdns

base_url="https://raw.githubusercontent.com/SINNOMBRE22/dnstt/main"

# Descargar binario principal
wget -q https://github.com/SINNOMBRE22/dnstt/raw/main/dns-server -O dns-server
chmod +x dns-server

# Descargar archivos auxiliares
for file in \
  remove-slow slowdns-info slowdns-drop slowdns-ssh slowdns-ssl \
  slowdns-socks slowdns-customservice stopdns; do
  wget -q "${base_url}/${file}" -O "${file}"
  chmod +x "${file}"
done

# Comando global
wget -q "${base_url}/slowdns" -O /bin/slowdns
chmod +x /bin/slowdns

clear
figlet -p -f slant SlowDNS
echo -e "\n${GREEN}✔ INSTALACIÓN COMPLETADA${RESET}\n"
echo -e "Use el comando: ${RED}slowdns${RESET}\n"

sleep 2

# ═══════════════════════════════
# ABRIR MENÚ
# ═══════════════════════════════
slowdns
