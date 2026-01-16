#!/bin/bash

# =====================================================
# GESTOR XRAY MODERNO - SINNOMBRE (Versión v2 con REALITY/XTLS)
# Versión: 2.0 - Actualizado a Xray, soporte VLESS, REALITY, XTLS
# =====================================================

# ===== LOGGING =====
LOGFILE="/var/log/xray_manager.log"
mkdir -p "$(dirname "$LOGFILE")"

# ===== RUTAS BASE SN =====
SN_DIR="/etc/SN"
SN_INSTALL="/etc/SN/install"
SN_USERS="/etc/SN/usuarios"

VPS_src="/etc/SN"
VPS_crt="/etc/SN/cert"

mkdir -p "$SN_DIR" "$SN_INSTALL" "$SN_USERS" "$VPS_crt"

# ===== ARCHIVOS XRAY =====
config="/usr/local/etc/xray/config.json"
temp=$(mktemp)

# ===== VALIDACIONES =====
numero='^[0-9]+$'

# ===== COLORES =====
R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
B='\033[0;34m'
C='\033[0;36m'
W='\033[1;37m'
N='\033[0m'

# ===== LOG FUNCTION =====
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $*" >> "$LOGFILE"
}

# ===== MENSAJES =====
msg() {
  case "$1" in
    -bar)   echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}" ;;
    -bar3)  echo -e "${R}──────────────────────────────────────────${N}" ;;
    -verd)  echo -e "${G}$2${N}" ;;
    -verm|-verm2) echo -e "${R}$2${N}" ;;
    -ama)   echo -e "${Y}$2${N}" ;;
    -azu)   echo -e "${C}$2${N}" ;;
    -ne)    echo -ne "$2" ;;
    *)      echo -e "$*" ;;
  esac
}

# ===== TITULO =====
title() {
  clear
  msg -bar
  echo -e "${W} $* ${N}"
  msg -bar
}

# ===== TEXTO =====
print_center() {
  msg "$1" "$2"
}

# ===== ENTER =====
enter() {
  read -p " Presione ENTER para continuar"
}

# ===== MENU =====
menu_func() {
  local i=1
  for opt in "$@"; do
    echo -e " ${G}$i)${N} $opt"
    ((i++))
  done
}

# ===== VOLVER =====
back() {
  msg -bar
  echo -e " ${Y}0)${N} Volver"
  msg -bar
}

# ===== SELECCIÓN =====
selection_fun() {
  local max=$1
  local opt
  while true; do
    read -p " Opción: " opt
    [[ "$opt" =~ ^[0-9]+$ && "$opt" -ge 0 && "$opt" -le "$max" ]] && {
      echo "$opt"
      return
    }
  done
}

# ===== INPUT =====
in_opcion() {
  read -p " $1: " opcion
}

# ===== CHECK DEPS =====
check_deps() {
    command -v jq >/dev/null 2>&1 || { msg -verm2 "jq no está instalado."; exit 1; }
    systemctl is-active --quiet xray || { msg -verm2 "xray no está corriendo."; return 1; }
    [[ -f "$config" ]] || { msg -verm2 "Config file no encontrado."; return 1; }
    return 0
}

# ===== VERIFICAR SI XRAY ESTÁ INSTALADO =====
is_installed() {
  check_deps
}

restart(){
    title "REINICIANDO XRAY"
    systemctl restart xray
    if systemctl is-active --quiet xray; then
        print_center -verd "xray restart success!"
        log "Xray reiniciado"
    else
        print_center -verm2 "xray restart fail!"
        log "Error en restart"
    fi
    msg -bar
    sleep 3
}

ins_xray(){
    title "INSTALANDO XRAY"
    print_center -ama "Instalación en progreso..."
    log "Instalando Xray"
    source <(curl -sSL https://raw.githubusercontent.com/SINNOMBRE22/SN/refs/heads/main/Sistema/xray_v2.sh) || { msg -verm2 "Error en instalación."; log "Error instalación"; return; }
    log "Instalación completa"
}

xray_tls(){
    db="$(ls ${VPS_crt})"
    if [[ ! "$(echo "$db"|grep '.crt')" = "" ]]; then
        cert=$(echo "$db"|grep '.crt')
        key=$(echo "$db"|grep '.key')
        DOMI=$(cat "${VPS_src}/dominio.txt")
        title "CERTIFICADO SSL ENCONTRADO"
        echo -e "$(msg -azu "DOMI:") $(msg -ama "$DOMI")"
        echo -e "$(msg -azu "CERT:") $(msg -ama "$cert")"
        echo -e "$(msg -azu "KEY:")  $(msg -ama "$key")"
        msg -bar
        msg -ne " Continuar [S/N]: " && read opcion_tls

        if [[ $opcion_tls = @(S|s) ]]; then
            cert=$(jq --arg a "${VPS_crt}/$cert" --arg b "${VPS_crt}/$key" '.inbounds[0].streamSettings.tlsSettings += {"certificates":[{"certificateFile":$a,"keyFile":$b}]}' < $config)
            domi=$(echo "$cert"|jq --arg a "$DOMI" '.inbounds[0] += {"domain":$a}')
            echo "$domi"|jq --arg a 'tls' '.inbounds[0].streamSettings += {"security":$a}' > $temp
            chmod 777 $temp
            mv -f $temp $config
            restart
            return
        fi
    fi

    title "CERTIFICADO TLS XRAY"
    echo -e "\033[1;37m"
    xray tls
    enter
}

removeXray(){
    read -p "Confirmar eliminación [y/N]: " confirm
    [[ "$confirm" =~ ^[yY]$ ]] || return
    log "Eliminando Xray"
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove
    rm -rf /usr/local/etc/xray >/dev/null 2>&1
    rm -rf /var/log/xray >/dev/null 2>&1
    rm -rf /usr/share/bash-completion/completions/xray >/dev/null 2>&1
    rm -rf /usr/local/bin/xray >/dev/null 2>&1
    crontab -l|sed '/SHELL=/d;/xray/d' > crontab.txt
    crontab crontab.txt >/dev/null 2>&1
    rm -f crontab.txt >/dev/null 2>&1
    systemctl restart cron >/dev/null 2>&1
    sed -i '/xray/d' ~/.bashrc
    source ~/.bashrc
    clear
    msg -bar
    print_center "XRAY REMOVIDO!"
    log "Xray eliminado"
    enter
    return 1
}

xray_stream(){
    title "PROTOCOLOS XRAY"
    echo -e "\033[1;37m"
    xray stream
    msg -bar
    read foo
}

port(){
    port=$(jq -r '.inbounds[0].port' $config)
    title "CONFIG PUERTO XRAY"
    print_center -azu "puerto actual: $(msg -ama "$port")"
    back
    in_opcion "Nuevo puerto"
    opcion=$(echo "$opcion" | tr -d '[[:space:]]')
    tput cuu1 && tput dl1
    if [[ -z "$opcion" ]]; then
        msg -ne "ingresa un puerto"
        sleep 2
        return
    elif [[ ! $opcion =~ $numero ]] || [[ "$opcion" -lt 1 ]] || [[ "$opcion" -gt 65535 ]]; then
        msg -ne "puerto inválido (1-65535)"
        sleep 2
        return
    elif [[ "$opcion" = "0" ]]; then
        return
    fi
    mv $config $temp
    jq --argjson a "$opcion" '.inbounds[0].port = $a' < $temp > $config
    chmod 777 $config
    rm $temp
    restart
}

address(){
    add=$(jq -r '.inbounds[0].domain' $config) && [[ $add = null ]] && add=$(wget -qO- ipv4.icanhazip.com)
    title "CONFIG address XRAY"
    print_center -azu "actual: $(msg -ama "$add")"
    back
    in_opcion "Nuevo address"
    opcion=$(echo "$opcion" | tr -d '[[:space:]]')
    tput cuu1 && tput dl1
    if [[ -z "$opcion" ]]; then
        msg -ne "ingresa un address"
        sleep 2
        return
    elif [[ "$opcion" = "0" ]]; then
        return
    fi
    mv $config $temp
    jq --arg a "$opcion" '.inbounds[0].domain = $a' < $temp > $config
    chmod 777 $config
    rm $temp
    restart
}

host(){
    host=$(jq -r '.inbounds[0].streamSettings.wsSettings.headers.Host' $config) && [[ $host = null ]] && host='sin host'
    title "CONFIG host XRAY"
    print_center -azu "Actual: $(msg -ama "$host")"
    back
    in_opcion "Nuevo host"
    opcion=$(echo "$opcion" | tr -d '[[:space:]]')
    tput cuu1 && tput dl1
    if [[ -z "$opcion" ]]; then
        msg -ne "ingresa un host"
        sleep 2
        return
    elif [[ "$opcion" = "0" ]]; then
        return
    fi
    mv $config $temp
    jq --arg a "$opcion" '.inbounds[0].streamSettings.wsSettings.headers.Host = $a' < $temp > $config
    chmod 777 $config
    rm $temp
    restart
}

path(){
    path=$(jq -r '.inbounds[0].streamSettings.wsSettings.path' $config) && [[ $path = null ]] && path=''
    title "CONFIG path XRAY"
    print_center -azu "Actual: $(msg -ama "$path")"
    back
    in_opcion "Nuevo path"
    opcion=$(echo "$opcion" | tr -d '[[:space:]]')
    tput cuu1 && tput dl1
    if [[ -z "$opcion" ]]; then
        msg -ne "ingresa un path"
        sleep 2
        return
    elif [[ "$opcion" = "0" ]]; then
        return
    fi
    mv $config $temp
    jq --arg a "$opcion" '.inbounds[0].streamSettings.wsSettings.path = $a' < $temp > $config
    chmod 777 $config
    rm $temp
    restart
}

reset(){
    title "RESTAURANDO AJUSTES XRAY"
    user=$(jq -c '.inbounds[0].settings.clients' < $config)
    systemctl stop xray
    cat > /usr/local/etc/xray/config.json <<EOF
{
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$(uuidgen)",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "www.google.com:443",
          "xver": 0,
          "serverNames": ["www.google.com"],
          "privateKey": "$(xray x25519 | grep Private | cut -d: -f2 | tr -d ' ')",
          "shortIds": [""]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF
    systemctl start xray
    chmod 777 $config
    sleep 2
    if [[ ! -z "$user" ]]; then
        title "RESTAURANDO USUARIOS"
        mv $config $temp
        jq --argjson a "$user" '.inbounds[0].settings += {clients:$a}' < $temp > $config
        chmod 777 $config
        sleep 2
        restart
    fi
}

# ===== AUTO-LIMPIEZA =====
trap 'rm -f "$temp"' EXIT

# ===== MENÚ =====
if ! is_installed; then
    while :
    do
        clear
        echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
        echo -e "${W}              XRAY MANAGER BY @SIN_NOMBRE22${N}"
        echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
        echo ""
        echo -e "${W}                     INSTALACIÓN${N}"
        echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
        echo -e "${R}[${Y}1${R}]${N}  ${C}INSTALAR XRAY${N}              ${R}[${Y}0${R}]${N}  ${C}VOLVER${N}"
        echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
        echo ""
        echo -ne "${W}Selecciona una opción: ${G}"
        read -r opcion
        case "${opcion:-}" in
            1) ins_xray; break ;;
            0) exit 0 ;;
            *)
                clear
                echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
                echo -e "${B}                   OPCIÓN INVÁLIDA${N}"
                echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
                sleep 2
                ;;
        esac
    done
fi

while :
do
    clear
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${W}              XRAY MANAGER BY @SIN_NOMBRE22${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo ""
    echo -e "${W}                       INSTALACIÓN${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${R}[${Y}1${R}]${N}  ${C}INSTALL/RE-REINSTALL XRAY${N}  ${R}[${Y}2${R}]${N}  ${C}DESINSTALAR XRAY${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${W}                   CONFIGURACIÓN BÁSICA${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${R}[${Y}3${R}]${N}  ${C}Configurar Puerto${N}"
    echo -e "${R}[${Y}4${R}]${N}  ${C}Configurar Address${N}"
    echo -e "${R}[${Y}5${R}]${N}  ${C}Configurar Host${N}"
    echo -e "${R}[${Y}6${R}]${N}  ${C}Configurar Path${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${W}                 CONFIGURACIÓN AVANZADA${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${R}[${Y}7${R}]${N}  ${C}Certificado SSL/TLS${N}         ${R}[${Y}8${R}]${N}  ${C}Protocolos Xray${N}"
    echo -e "${R}[${Y}9${R}]${N}  ${C}Configuración Nativa${N}         ${R}[${Y}10${R}]${N} ${C}Restablecer Ajustes${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${R}[${Y}0${R}]${N}  ${C}VOLVER${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo ""
    echo -ne "${W}Selecciona una opción: ${G}"
    read -r opcion
    case "${opcion:-}" in
        1)ins_xray;;
        2)removeXray;;
        3)port;;
        4)address;;
        5)host;;
        6)path;;
        7)xray_tls;;
        8)xray_stream;;
        9)n_xray;;
        10)reset;;
        0)break;;
        *)
            clear
            echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
            echo -e "${B}                   OPCIÓN INVÁLIDA${N}"
            echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
            sleep 2
            ;;
    esac
done
