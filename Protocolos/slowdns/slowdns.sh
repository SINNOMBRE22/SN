#!/bin/bash
# ===============================================
#   INSTALADOR SLOWDNS (VERSIÓN EN ESPAÑOL)
# ===============================================

clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   INSTALADOR AUTOMÁTICO SLOWDNS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ===============================================
# CONFIGURAR IPTABLES
# ===============================================

echo "[+] Configurando reglas de red..."

iptables -I INPUT -p udp --dport 5300 -j ACCEPT
iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300

netfilter-persistent save &>/dev/null
netfilter-persistent reload &>/dev/null

echo "[✔] IPTABLES configurado correctamente"
echo ""

# ===============================================
# LIMPIAR ARCHIVOS ANTERIORES
# ===============================================

echo "[+] Eliminando configuraciones antiguas..."
rm -rf /root/nsdomain
rm -f nsdomain
echo "[✔] Limpieza completada"
echo ""

# ===============================================
# SOLICITAR DOMINIO
# ===============================================

read -rp "Ingrese su dominio (ej: midominio.com): " domain
read -rp "Ingrese subdominio (ej: vpn): " sub

SUB_DOMAIN=${sub}.${domain}
NS_DOMAIN=slowdns-${SUB_DOMAIN}

echo "$NS_DOMAIN" > /root/nsdomain
nameserver=$(cat /root/nsdomain)

echo ""
echo "[✔] Dominio configurado: $NS_DOMAIN"
echo ""

# ===============================================
# INSTALAR DEPENDENCIAS
# ===============================================

echo "[+] Instalando paquetes necesarios..."

apt update -y
apt install -y python3 python3-dnslib net-tools
apt install -y dnsutils curl wget git screen cron iptables sudo gnutls-bin dos2unix debconf-utils dropbear whois

service cron restart

echo "[✔] Paquetes instalados correctamente"
echo ""

# ===============================================
# CONFIGURAR SSH
# ===============================================

echo "[+] Configurando puertos SSH adicionales..."

echo "Port 2222" >> /etc/ssh/sshd_config
echo "Port 2269" >> /etc/ssh/sshd_config

sed -i 's/#AllowTcpForwarding yes/AllowTcpForwarding yes/g' /etc/ssh/sshd_config

service ssh restart

echo "[✔] SSH configurado (puertos 2222 y 2269)"
echo ""

# ===============================================
# INSTALAR SLOWDNS
# ===============================================

echo "[+] Instalando SlowDNS..."

rm -rf /etc/slowdns
mkdir -m 777 /etc/slowdns

wget -q -O /etc/slowdns/server.key "https://raw.githubusercontent.com/fisabiliyusri/SLDNS/main/slowdns/server.key"
wget -q -O /etc/slowdns/server.pub "https://raw.githubusercontent.com/fisabiliyusri/SLDNS/main/slowdns/server.pub"
wget -q -O /etc/slowdns/sldns-server "https://raw.githubusercontent.com/fisabiliyusri/SLDNS/main/slowdns/sldns-server"
wget -q -O /etc/slowdns/sldns-client "https://raw.githubusercontent.com/fisabiliyusri/SLDNS/main/slowdns/sldns-client"

chmod +x /etc/slowdns/*

echo "[✔] SlowDNS instalado correctamente"
echo ""

# ===============================================
# CREAR SERVICIO CLIENTE
# ===============================================

echo "[+] Creando servicio cliente..."

cat > /etc/systemd/system/client-sldns.service << END
[Unit]
Description=Cliente SlowDNS
After=network.target

[Service]
Type=simple
User=root
ExecStart=/etc/slowdns/sldns-client -udp 8.8.8.8:53 --pubkey-file /etc/slowdns/server.pub $nameserver 127.0.0.1:2222
Restart=always

[Install]
WantedBy=multi-user.target
END

# ===============================================
# CREAR SERVICIO SERVIDOR
# ===============================================

echo "[+] Creando servicio servidor..."

cat > /etc/systemd/system/server-sldns.service << END
[Unit]
Description=Servidor SlowDNS
After=network.target

[Service]
Type=simple
User=root
ExecStart=/etc/slowdns/sldns-server -udp :5300 -privkey-file /etc/slowdns/server.key $nameserver 127.0.0.1:2269
Restart=always

[Install]
WantedBy=multi-user.target
END

# ===============================================
# ACTIVAR SERVICIOS
# ===============================================

echo "[+] Activando servicios..."

systemctl daemon-reload

systemctl enable client-sldns
systemctl enable server-sldns

systemctl restart client-sldns
systemctl restart server-sldns

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   INSTALACIÓN COMPLETADA ✔"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Dominio SlowDNS: $NS_DOMAIN"
echo "Puerto DNS: 53 (redirigido a 5300)"
echo "SSH Cliente: 2222"
echo "SSH Interno: 2269"
echo ""
