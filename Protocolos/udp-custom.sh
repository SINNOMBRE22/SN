#!/bin/bash
set -euo pipefail

# =========================================================
# SinNombre v1.0 - UDPCUSTOM (UDP Custom Server) Estilo ADMRufu (Rufu99)
# Basado en: https://github.com/Redjoker256/Udpcustom
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

instala_udpcustom(){
  clear
  hr
  echo -e "${W}          INSTALADOR UDPCUSTOM${N}"
  hr

  echo -e "${Y}Instalando dependencias...${N}"
  apt-get update >/dev/null 2>&1
  apt-get install -y screen wget curl jq unzip >/dev/null 2>&1

  echo -e "${Y}Descargando binarios...${N}"
  mkdir -p /etc/SN/udpcustom
  cd /etc/SN/udpcustom

  # Descargar badvpn-udpgw desde el repo
  wget -O badvpn-udpgw https://github.com/Redjoker256/Udpcustom/raw/main/badvpn-udpgw >/dev/null 2>&1
  chmod +x badvpn-udpgw

  # Crear script de inicio
  cat > start.sh <<'EOF'
#!/bin/bash
screen -dmS udpcustom /etc/SN/udpcustom/badvpn-udpgw --listen-addr 0.0.0.0:7300 --max-clients 1000 --max-connections-for-client 10
EOF
  chmod +x start.sh

  # Crear servicio systemd
  cat > /etc/systemd/system/udpcustom.service <<EOF
[Unit]
Description=UDPCustom UDP Gateway
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/SN/udpcustom
ExecStart=/etc/SN/udpcustom/badvpn-udpgw --listen-addr 0.0.0.0:7300 --max-clients 1000 --max-connections-for-client 10
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable udpcustom.service >/dev/null 2>&1

  echo -e "${Y}Iniciando servicio...${N}"
  systemctl start udpcustom.service >/dev/null 2>&1

  # Abrir puerto en firewall
  if command -v ufw >/dev/null 2>&1; then
    ufw allow 7300/udp >/dev/null 2>&1
  fi
  iptables -I INPUT -p udp --dport 7300 -j ACCEPT >/dev/null 2>&1

  clear
  hr
  echo -e "${G}UDPCUSTOM INSTALADO Y ACTIVADO!${N}"
  hr
  echo -e "${Y}Puerto: 7300 UDP${N}"
  echo -e "${Y}Para usar: Conecta tu juego al IP del VPS en puerto 7300${N}"
  pause
}

fun_udpcustom(){
  if [[ -e /etc/systemd/system/udpcustom.service ]]; then
    STATUS=""
    if systemctl is-active --quiet udpcustom.service; then
      STATUS="${G}[ONLINE]${N}"
    else
      STATUS="${R}[OFFLINE]${N}"
    fi

    clear
    hr
    echo -e "${W}          CONFIGURACION UDPCUSTOM${N}"
    hr
    echo -e "${R}[${Y}1${R}]${N} ${C}INICIAR O PARAR UDPCUSTOM $STATUS${N}"
    echo -e "${R}[${Y}2${R}]${N} ${C}REINICIAR UDPCUSTOM${N}"
    echo -e "${R}[${Y}3${R}]${N} ${R}DESINSTALAR UDPCUSTOM${N}"
    hr
    echo -e "${R}[${Y}0${R}]${N} ${W}VOLVER${N}"
    hr
    echo ""
    echo -ne "${W}Selecciona una opcion: ${G}"
    read -r opcion

    case "${opcion:-}" in
      3)
        clear
        hr
        echo -ne "${W}QUIERES DESINSTALAR UDPCUSTOM? [Y/N]: ${G}"
        read -r REMOVE
        hr
        if [[ "$REMOVE" = @(y|Y) ]]; then
          systemctl stop udpcustom.service >/dev/null 2>&1
          systemctl disable udpcustom.service >/dev/null 2>&1
          rm -f /etc/systemd/system/udpcustom.service
          systemctl daemon-reload
          rm -rf /etc/SN/udpcustom
          iptables -D INPUT -p udp --dport 7300 -j ACCEPT >/dev/null 2>&1
          if command -v ufw >/dev/null 2>&1; then
            ufw delete allow 7300/udp >/dev/null 2>&1
          fi
          clear
          hr
          echo -e "${G}UDPCUSTOM desinstalado!${N}"
          pause
        else
          clear
          hr
          echo -e "${R}Desinstalacion abortada!${N}"
          pause
        fi
        return 0 ;;
      2)
        echo -e "${W}Reiniciando UDPCUSTOM...${N}"
        systemctl restart udpcustom.service >/dev/null 2>&1
        echo -e "${G}Reiniciado!${N}"
        pause ;;
      1)
        if systemctl is-active --quiet udpcustom.service; then
          systemctl stop udpcustom.service >/dev/null 2>&1
          echo -e "${R}UDPCUSTOM detenido${N}"
        else
          systemctl start udpcustom.service >/dev/null 2>&1
          echo -e "${G}UDPCUSTOM iniciado${N}"
        fi
        pause ;;
      0)
        return 1 ;;
      *)
        echo -e "${B}Opcion invalida${N}"; sleep 1 ;;
    esac
    return 0
  fi

  instala_udpcustom
}

main_menu(){
  require_root

  while true; do
    fun_udpcustom || break
  done
}

main_menu
