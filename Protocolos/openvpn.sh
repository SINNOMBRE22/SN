#!/bin/bash
set -euo pipefail

# =========================================================
# SinNombre v1.0 - OPENVPN (VPN Server) Estilo ADMRufu (Rufu99)
# Archivo: SN/Protocolos/openvpn.sh
# =========================================================

R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
B='\033[0;34m'
C='\033[0;36m'
W='\033[1;37m'
N='\033[0m'
D='\033[2m'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

pause(){ echo ""; read -r -p "Presiona Enter para continuar..."; }
hr(){ echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"; }
sep(){ echo -e "${R}------------------------------------------------------------${N}"; }

require_root(){ [[ "${EUID:-$(id -u)}" -eq 0 ]] || { echo -e "${R}Ejecuta como root.${N}"; exit 1; }; }

mportas() {
  ss -H -lnt 2>/dev/null | awk '{print $4}' | awk -F: '{print $NF}' | sort -n | uniq
}

fun_ip(){
  curl -fsS --max-time 2 ifconfig.me 2>/dev/null || echo "127.0.0.1"
}

# Detect system
if [[ -e /etc/debian_version ]]; then
  OS=debian
  GROUPNAME=nogroup
  RCLOCAL='/etc/rc.local'
elif [[ -e /etc/centos-release || -e /etc/redhat-release ]]; then
  OS=centos
  GROUPNAME=nobody
  RCLOCAL='/etc/rc.d/rc.local'
else
  echo -e "${R}Sistema no compatible para este script${N}"
  exit 1
fi

agrega_dns(){
  echo -e "${Y}Escriba el HOST DNS que desea Agregar${N}"
  read -r -p " [NewDNS]: " SDNS
  cat /etc/hosts | grep -v "$SDNS" > /etc/hosts.bak && mv -f /etc/hosts.bak /etc/hosts
  if [[ -e /etc/opendns ]]; then
    cat /etc/opendns > /tmp/opnbak
    mv -f /tmp/opnbak /etc/opendns
    echo "$SDNS" >> /etc/opendns
  else
    echo "$SDNS" > /etc/opendns
  fi
  [[ -z ${NEWDNS:-} ]] && NEWDNS="$SDNS" || NEWDNS="$NEWDNS $SDNS"
  unset SDNS
}

dns_fun(){
  case $1 in
    1)
      if grep -q "127.0.0.53" "/etc/resolv.conf"; then
        RESOLVCONF='/run/systemd/resolve/resolv.conf'
      else
        RESOLVCONF='/etc/resolv.conf'
      fi
      grep -v '#' "$RESOLVCONF" | grep 'nameserver' | grep -E -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | while read -r line; do
        echo "push \"dhcp-option DNS $line\"" >> /etc/openvpn/server.conf
      done ;;
    2) #cloudflare
      echo 'push "dhcp-option DNS 1.1.1.1"' >> /etc/openvpn/server.conf
      echo 'push "dhcp-option DNS 1.0.0.1"' >> /etc/openvpn/server.conf ;;
    3) #google
      echo 'push "dhcp-option DNS 8.8.8.8"' >> /etc/openvpn/server.conf
      echo 'push "dhcp-option DNS 8.8.4.4"' >> /etc/openvpn/server.conf ;;
    4) #OpenDNS
      echo 'push "dhcp-option DNS 208.67.222.222"' >> /etc/openvpn/server.conf
      echo 'push "dhcp-option DNS 208.67.220.220"' >> /etc/openvpn/server.conf ;;
    5) #Verisign
      echo 'push "dhcp-option DNS 64.6.64.6"' >> /etc/openvpn/server.conf
      echo 'push "dhcp-option DNS 64.6.65.6"' >> /etc/openvpn/server.conf ;;
    6) #Quad9
      echo 'push "dhcp-option DNS 9.9.9.9"' >> /etc/openvpn/server.conf
      echo 'push "dhcp-option DNS 149.112.112.112"' >> /etc/openvpn/server.conf ;;
    7) #UncensoredDNS
      echo 'push "dhcp-option DNS 91.239.100.100"' >> /etc/openvpn/server.conf
      echo 'push "dhcp-option DNS 89.233.43.71"' >> /etc/openvpn/server.conf ;;
  esac
}

instala_ovpn(){
  clear
  hr
  echo -e "${W}          INSTALADOR DE OPENVPN${N}"
  hr

  IP=$(ip addr | grep 'inet' | grep -v inet6 | grep -vE '127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
  if echo "$IP" | grep -qE '^(10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.|192\.168)'; then
    PUBLICIP=$(fun_ip)
  fi

  echo -e "${Y}Seleccione el protocolo de conexiones OpenVPN${N}"
  hr
  echo -e "${R}[${Y}1${R}]${N} ${C}UDP${N}"
  echo -e "${R}[${Y}2${R}]${N} ${C}TCP${N}"
  hr

  PROTOCOL=""
  while [[ -z "$PROTOCOL" ]]; do
    echo -ne "${W}Opcion: ${G}"
    read -r PROTOCOL
    case $PROTOCOL in
      1) PROTOCOL=udp; echo -e "${Y}PROTOCOLO: ${G}UDP${N}" ;;
      2) PROTOCOL=tcp; echo -e "${Y}PROTOCOLO: ${G}TCP${N}" ;;
      *) echo -e "${R}Selecciona una opcion entre 1 y 2${N}"; sleep 2; PROTOCOL="" ;;
    esac
  done

  hr
  echo -e "${W}Ingresa un puerto OpenVPN (Default 1194)${N}"
  hr
  PORT=""
  while [[ -z "$PORT" ]]; do
    echo -ne "${W}Puerto: ${G}"
    read -r PORT
    if [[ -z "$PORT" ]]; then
      PORT="1194"
    elif [[ ! "$PORT" =~ ^[0-9]+$ ]]; then
      echo -e "${R}Ingresa solo numeros${N}"; sleep 2; PORT=""
    fi
    if mportas | grep -qw "$PORT"; then
      echo -e "${R}Puerto en uso${N}"; sleep 2; PORT=""
    fi
  done
  echo -e "${Y}PUERTO: ${G}$PORT${N}"

  hr
  echo -e "${W}Seleccione DNS (default VPS)${N}"
  hr
  echo -e "${R}[${Y}1${R}]${N} ${C}DNS del Sistema${N}"
  echo -e "${R}[${Y}2${R}]${N} ${C}Cloudflare${N}"
  echo -e "${R}[${Y}3${R}]${N} ${C}Google${N}"
  echo -e "${R}[${Y}4${R}]${N} ${C}OpenDNS${N}"
  echo -e "${R}[${Y}5${R}]${N} ${C}Verisign${N}"
  echo -e "${R}[${Y}6${R}]${N} ${C}Quad9${N}"
  echo -e "${R}[${Y}7${R}]${N} ${C}UncensoredDNS${N}"
  hr

  DNS=""
  while [[ -z "$DNS" ]]; do
    echo -ne "${W}Opcion: ${G}"
    read -r DNS
    if [[ -z "$DNS" ]]; then
      DNS="1"
    elif [[ ! "$DNS" =~ ^[0-9]+$ ]] || [[ "$DNS" -lt 1 ]] || [[ "$DNS" -gt 7 ]]; then
      echo -e "${R}Ingresa solo numeros entre 1 y 7${N}"; sleep 2; DNS=""
    fi
  done

  case $DNS in
    1) P_DNS="DNS del Sistema" ;;
    2) P_DNS="Cloudflare" ;;
    3) P_DNS="Google" ;;
    4) P_DNS="OpenDNS" ;;
    5) P_DNS="Verisign" ;;
    6) P_DNS="Quad9" ;;
    7) P_DNS="UncensoredDNS" ;;
  esac
  echo -e "${Y}DNS: ${G}$P_DNS${N}"

  hr
  echo -e "${W}Seleccione la codificacion para el canal de datos${N}"
  hr
  echo -e "${R}[${Y}1${R}]${N} ${C}AES-128-CBC${N}"
  echo -e "${R}[${Y}2${R}]${N} ${C}AES-192-CBC${N}"
  echo -e "${R}[${Y}3${R}]${N} ${C}AES-256-CBC${N}"
  echo -e "${R}[${Y}4${R}]${N} ${C}CAMELLIA-128-CBC${N}"
  echo -e "${R}[${Y}5${R}]${N} ${C}CAMELLIA-192-CBC${N}"
  echo -e "${R}[${Y}6${R}]${N} ${C}CAMELLIA-256-CBC${N}"
  echo -e "${R}[${Y}7${R}]${N} ${C}SEED-CBC${N}"
  echo -e "${R}[${Y}8${R}]${N} ${C}NONE${N}"
  hr

  CIPHER=""
  while [[ -z "$CIPHER" ]]; do
    echo -ne "${W}Opcion: ${G}"
    read -r CIPHER
    if [[ -z "$CIPHER" ]]; then
      CIPHER="1"
    elif [[ ! "$CIPHER" =~ ^[0-9]+$ ]] || [[ "$CIPHER" -lt 1 ]] || [[ "$CIPHER" -gt 8 ]]; then
      echo -e "${R}Ingresa solo numeros entre 1 y 8${N}"; sleep 2; CIPHER=""
    fi
  done

  case $CIPHER in
    1) CIPHER="cipher AES-128-CBC" ;;
    2) CIPHER="cipher AES-192-CBC" ;;
    3) CIPHER="cipher AES-256-CBC" ;;
    4) CIPHER="cipher CAMELLIA-128-CBC" ;;
    5) CIPHER="cipher CAMELLIA-192-CBC" ;;
    6) CIPHER="cipher CAMELLIA-256-CBC" ;;
    7) CIPHER="cipher SEED-CBC" ;;
    8) CIPHER="cipher none" ;;
  esac

  codi=$(echo "$CIPHER" | awk '{print $2}')
  echo -e "${Y}CODIFICACION: ${G}$codi${N}"
  hr
  echo -e "${Y}Estamos listos para configurar su servidor OpenVPN${N}"
  pause

  if [[ "$OS" = 'debian' ]]; then
    apt-get update >/dev/null 2>&1
    apt-get install openvpn iptables openssl ca-certificates -y >/dev/null 2>&1
  else
    yum install epel-release -y >/dev/null 2>&1
    yum install openvpn iptables openssl ca-certificates -y >/dev/null 2>&1
  fi

  # Generar certificados con openssl (sin easy-rsa)
  mkdir -p /etc/openvpn/easy-rsa/keys
  cd /etc/openvpn/easy-rsa

  # Generar CA
  openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -subj "/C=US/ST=State/L=City/O=Organization/CN=VPS-SN-CA" -keyout keys/ca.key -out keys/ca.crt >/dev/null 2>&1

  # Generar server key y cert
  openssl req -new -newkey rsa:2048 -days 3650 -nodes -subj "/C=US/ST=State/L=City/O=Organization/CN=server" -keyout keys/server.key -out keys/server.csr >/dev/null 2>&1
  openssl x509 -req -days 3650 -in keys/server.csr -CA keys/ca.crt -CAkey keys/ca.key -CAcreateserial -out keys/server.crt >/dev/null 2>&1

  # Generar DH
  openssl dhparam -out keys/dh.pem 2048 >/dev/null 2>&1

  # Generar TA key
  openvpn --genkey --secret keys/ta.key >/dev/null 2>&1

  # Copiar a /etc/openvpn
  cp keys/ca.crt keys/ca.key keys/server.crt keys/server.key keys/dh.pem keys/ta.key /etc/openvpn
  chown nobody:"$GROUPNAME" /etc/openvpn/ta.key

  cat > /etc/openvpn/server.conf <<EOF
port $PORT
proto $PROTOCOL
dev tun
sndbuf 0
rcvbuf 0
ca ca.crt
cert server.crt
key server.key
dh dh.pem
auth SHA512
tls-auth ta.key 0
topology subnet
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
EOF

  dns_fun "$DNS"

  cat >> /etc/openvpn/server.conf <<EOF
keepalive 10 120
$CIPHER
user nobody
group $GROUPNAME
persist-key
persist-tun
status openvpn-status.log
verb 3
EOF

  PLUGIN=$(locate openvpn-plugin-auth-pam.so 2>/dev/null | head -1)
  [[ -n "$PLUGIN" ]] && cat >> /etc/openvpn/server.conf <<EOF
client-to-client
client-cert-not-required
username-as-common-name
plugin $PLUGIN login
EOF

  echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/30-openvpn-forward.conf
  echo 1 > /proc/sys/net/ipv4/ip_forward

  if pgrep firewalld >/dev/null 2>&1; then
    firewall-cmd --zone=public --add-port="$PORT"/"$PROTOCOL" >/dev/null 2>&1
    firewall-cmd --zone=trusted --add-source=10.8.0.0/24 >/dev/null 2>&1
    firewall-cmd --permanent --zone=public --add-port="$PORT"/"$PROTOCOL" >/dev/null 2>&1
    firewall-cmd --permanent --zone=trusted --add-source=10.8.0.0/24 >/dev/null 2>&1
    firewall-cmd --direct --add-rule ipv4 nat POSTROUTING 0 -s 10.8.0.0/24 ! -d 10.8.0.0/24 -j SNAT --to "$IP" >/dev/null 2>&1
    firewall-cmd --permanent --direct --add-rule ipv4 nat POSTROUTING 0 -s 10.8.0.0/24 ! -d 10.8.0.0/24 -j SNAT --to "$IP" >/dev/null 2>&1
  else
    if [[ "$OS" = 'debian' && ! -e "$RCLOCAL" ]]; then
      echo '#!/bin/sh -e
exit 0' > "$RCLOCAL"
    fi
    chmod +x "$RCLOCAL"
    iptables -t nat -A POSTROUTING -s 10.8.0.0/24 ! -d 10.8.0.0/24 -j SNAT --to "$IP"
    sed -i "1 a\iptables -t nat -A POSTROUTING -s 10.8.0.0/24 ! -d 10.8.0.0/24 -j SNAT --to $IP" "$RCLOCAL"
    if iptables -L -n | grep -qE '^(REJECT|DROP)'; then
      iptables -I INPUT -p "$PROTOCOL" --dport "$PORT" -j ACCEPT
      iptables -I FORWARD -s 10.8.0.0/24 -j ACCEPT
      iptables -I FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
      sed -i "1 a\iptables -I INPUT -p $PROTOCOL --dport $PORT -j ACCEPT" "$RCLOCAL"
      sed -i "1 a\iptables -I FORWARD -s 10.8.0.0/24 -j ACCEPT" "$RCLOCAL"
      sed -i "1 a\iptables -I FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT" "$RCLOCAL"
    fi
  fi

  if sestatus 2>/dev/null | grep "Current mode" | grep -q "enforcing" && [[ "$PORT" != '1194' ]]; then
    if ! hash semanage 2>/dev/null; then
      yum install policycoreutils-python -y >/dev/null 2>&1
    fi
    semanage port -a -t openvpn_port_t -p "$PROTOCOL" "$PORT" >/dev/null 2>&1
  fi

  if [[ "$OS" = 'debian' ]]; then
    if pgrep systemd-journal >/dev/null 2>&1; then
      systemctl restart openvpn@server.service >/dev/null 2>&1
    else
      /etc/init.d/openvpn restart >/dev/null 2>&1
    fi
  else
    if pgrep systemd-journal >/dev/null 2>&1; then
      systemctl restart openvpn@server.service >/dev/null 2>&1
      systemctl enable openvpn@server.service >/dev/null 2>&1
    else
      service openvpn restart >/dev/null 2>&1
      chkconfig openvpn on >/dev/null 2>&1
    fi
  fi

  if [[ -n "${PUBLICIP:-}" ]]; then
    IP="$PUBLICIP"
  fi

  cat > /etc/openvpn/client-common.txt <<EOF
# OVPN_ACCESS_SERVER_PROFILE=VPS-SN
client
dev tun
proto $PROTOCOL
sndbuf 0
rcvbuf 0
remote $IP $PORT
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
auth SHA512
$CIPHER
setenv opt block-outside-dns
key-direction 1
verb 3
auth-user-pass
EOF

  clear
  hr
  echo -e "${G}Configuracion Finalizada!${N}"
  hr
  echo -e "${Y}Crear un usuario SSH para generar el (.ovpn)!${N}"
  pause
}

edit_ovpn_host(){
  echo -e "${Y}CONFIGURACION HOST DNS OPENVPN${N}"
  hr
  DDNS=""
  while [[ "$DDNS" != @(n|N) ]]; do
    echo -ne "${Y}Agregar host [S/N]: ${G}"
    read -r -i "n" DDNS
    [[ "$DDNS" = @(s|S|y|Y) ]] && agrega_dns
  done
  [[ -n "${NEWDNS:-}" ]] && sed -i "/127.0.0.1[[:blank:]]\+localhost/a 127.0.0.1 $NEWDNS" /etc/hosts
  hr
  echo -e "${Y}Es Necesario el Reboot del Servidor Para${N}"
  echo -e "${Y}Para que las configuraciones sean efectudas${N}"
  pause
}

fun_openvpn(){
  if [[ -e /etc/openvpn/server.conf ]]; then
    OPENBAR=""
    if systemctl is-active --quiet openvpn@server.service 2>/dev/null || service openvpn status 2>/dev/null | grep -q "active"; then
      OPENBAR="${G}[ONLINE]${N}"
    else
      OPENBAR="${R}[OFFLINE]${N}"
    fi

    clear
    hr
    echo -e "${W}          CONFIGURACION OPENVPN${N}"
    hr
    echo -e "${R}[${Y}1${R}]${N} ${C}INICIAR O PARAR OPENVPN $OPENBAR${N}"
    echo -e "${R}[${Y}2${R}]${N} ${C}EDITAR CONFIGURACION CLIENTE (NANO)${N}"
    echo -e "${R}[${Y}3${R}]${N} ${C}EDITAR CONFIGURACION SERVIDOR (NANO)${N}"
    echo -e "${R}[${Y}4${R}]${N} ${C}CAMBIAR HOST DE OPENVPN${N}"
    echo -e "${R}[${Y}5${R}]${N} ${R}DESINSTALAR OPENVPN${N}"
    hr
    echo -e "${R}[${Y}0${R}]${N} ${W}VOLVER${N}"
    hr
    echo ""
    echo -ne "${W}Selecciona una opcion: ${G}"
    read -r xption

    case "${xption:-}" in
      5)
        clear
        hr
        echo -ne "${W}QUIERES DESINTALAR OPENVPN? [Y/N]: ${G}"
        read -r REMOVE
        hr
        if [[ "$REMOVE" = @(y|Y) ]]; then
          PORT=$(grep '^port ' /etc/openvpn/server.conf | cut -d " " -f 2)
          PROTOCOL=$(grep '^proto ' /etc/openvpn/server.conf | cut -d " " -f 2)
          if pgrep firewalld >/dev/null 2>&1; then
            IP=$(firewall-cmd --direct --get-rules ipv4 nat POSTROUTING | grep '\-s 10.8.0.0/24 '"'"'!'"'"' -d 10.8.0.0/24 -j SNAT --to ' | cut -d " " -f 10)
            firewall-cmd --zone=public --remove-port="$PORT"/"$PROTOCOL" >/dev/null 2>&1
            firewall-cmd --zone=trusted --remove-source=10.8.0.0/24 >/dev/null 2>&1
            firewall-cmd --permanent --zone=public --remove-port="$PORT"/"$PROTOCOL" >/dev/null 2>&1
            firewall-cmd --permanent --zone=trusted --remove-source=10.8.0.0/24 >/dev/null 2>&1
            firewall-cmd --direct --remove-rule ipv4 nat POSTROUTING 0 -s 10.8.0.0/24 ! -d 10.8.0.0/24 -j SNAT --to "$IP" >/dev/null 2>&1
            firewall-cmd --permanent --direct --remove-rule ipv4 nat POSTROUTING 0 -s 10.8.0.0/24 ! -d 10.8.0.0/24 -j SNAT --to "$IP" >/dev/null 2>&1
          else
            IP=$(grep 'iptables -t nat -A POSTROUTING -s 10.8.0.0/24 ! -d 10.8.0.0/24 -j SNAT --to ' "$RCLOCAL" | cut -d " " -f 14)
            iptables -t nat -D POSTROUTING -s 10.8.0.0/24 ! -d 10.8.0.0/24 -j SNAT --to "$IP" >/dev/null 2>&1
            sed -i '/iptables -t nat -A POSTROUTING -s 10.8.0.0\/24 ! -d 10.8.0.0\/24 -j SNAT --to /d' "$RCLOCAL"
            if iptables -L -n | grep -qE '^ACCEPT'; then
              iptables -D INPUT -p "$PROTOCOL" --dport "$PORT" -j ACCEPT >/dev/null 2>&1
              iptables -D FORWARD -s 10.8.0.0/24 -j ACCEPT >/dev/null 2>&1
              iptables -D FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT >/dev/null 2>&1
              sed -i "/iptables -I INPUT -p $PROTOCOL --dport $PORT -j ACCEPT/d" "$RCLOCAL"
              sed -i "/iptables -I FORWARD -s 10.8.0.0\/24 -j ACCEPT/d" "$RCLOCAL"
              sed -i "/iptables -I FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT/d" "$RCLOCAL"
            fi
          fi
          if sestatus 2>/dev/null | grep "Current mode" | grep -q "enforcing" && [[ "$PORT" != '1194' ]]; then
            semanage port -d -t openvpn_port_t -p "$PROTOCOL" "$PORT" >/dev/null 2>&1
          fi
          if [[ "$OS" = 'debian' ]]; then
            apt-get remove --purge -y openvpn >/dev/null 2>&1
          else
            yum remove openvpn -y >/dev/null 2>&1
          fi
          rm -rf /etc/openvpn
          rm -f /etc/sysctl.d/30-openvpn-forward.conf
          clear
          hr
          echo -e "${G}OpenVPN removido!${N}"
          pause
        else
          clear
          hr
          echo -e "${R}Desinstalacion abortada!${N}"
          pause
        fi
        return 0 ;;
      2)
        nano /etc/openvpn/client-common.txt ;;
      3)
        nano /etc/openvpn/server.conf ;;
      4)
        edit_ovpn_host ;;
      1)
        if systemctl is-active --quiet openvpn@server.service; then
          systemctl stop openvpn@server.service >/dev/null 2>&1 || service openvpn stop >/dev/null 2>&1
          echo -e "${R}OpenVPN detenido${N}"
        else
          systemctl start openvpn@server.service >/dev/null 2>&1 || service openvpn start >/dev/null 2>&1
          echo -e "${G}OpenVPN iniciado${N}"
        fi
        pause ;;
      0)
        return 1 ;;
      *)
        echo -e "${B}Opcion invalida${N}"; sleep 1 ;;
    esac
    return 0
  fi

  instala_ovpn
}

main_menu(){
  require_root

  while true; do
    fun_openvpn || break
  done
}

main_menu
