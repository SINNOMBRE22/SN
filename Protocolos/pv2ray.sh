#!/bin/bash

# =====================================================
# AUTONOMÍA V2RAY - SINNOMBRE (Corregido y Mejorado)

# Versión: 1.1 - Corregido ejecución, líneas truncadas, agregado checks y features
# =====================================================

# ===== LOGGING =====
LOGFILE="/var/log/v2ray_manager.log"
mkdir -p "$(dirname "$LOGFILE")"

# ===== RUTAS BASE SN =====
SN_DIR="/etc/SN"
SN_INSTALL="/etc/SN/install"
SN_USERS="/etc/SN/usuarios"

VPS_src="/etc/SN"
VPS_crt="/etc/SN/cert"

mkdir -p "$SN_DIR" "$SN_INSTALL" "$SN_USERS" "$VPS_crt"

# ===== ARCHIVOS V2RAY =====
config="/etc/v2ray/config.json"
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
    command -v v2ray >/dev/null 2>&1 || { msg -verm2 "v2ray no está instalado."; return 1; }
    [[ -f "$config" ]] || { msg -verm2 "Config file no encontrado."; return 1; }
    return 0
}

# ===== VERIFICAR SI V2RAY ESTÁ INSTALADO =====
is_installed() {
  check_deps
}

restart(){
    title "REINICIANDO V2RAY"
    if v2ray restart 2>&1 | grep -q "success"; then
        print_center -verd "v2ray restart success!"
        log "V2Ray reiniciado"
    else
        print_center -verm2 "v2ray restart fail!"
        log "Error en restart"
    fi
    msg -bar
    sleep 3
}

ins_v2r(){
    title "INSTALANDO V2RAY"
    print_center -ama "Instalación en progreso..."
    log "Instalando V2Ray"
    source <(curl -sSL https://raw.githubusercontent.com/SINNOMBRE22/SN/refs/heads/main/Sistema/v2ray.sh) || { msg -verm2 "Error en instalación."; log "Error instalación"; return; }
    log "Instalación completa"
}

v2ray_tls(){
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

    title "CERTIFICADO TLS V2RAY"
    echo -e "\033[1;37m"
    v2ray tls
    enter
}

removeV2Ray(){
    read -p "Confirmar eliminación [y/N]: " confirm
    [[ "$confirm" =~ ^[yY]$ ]] || return
    log "Eliminando V2Ray"
    bash <(curl -L -s https://multi.netlify.app/go.sh) --remove >/dev/null 2>&1
    rm -rf /etc/v2ray >/dev/null 2>&1
    rm -rf /var/log/v2ray >/dev/null 2>&1
    bash <(curl -L -s https://multi.netlify.app/go.sh) --remove -x >/dev/null 2>&1
    rm -rf /etc/xray >/dev/null 2>&1
    rm -rf /var/log/xray >/dev/null 2>&1
    bash <(curl -L -s https://multi.netlify.app/v2ray_util/global_setting/clean_iptables.sh)
    pip uninstall v2ray_util -y
    rm -rf /usr/share/bash-completion/completions/v2ray.bash >/dev/null 2>&1
    rm -rf /usr/share/bash-completion/completions/v2ray >/dev/null 2>&1
    rm -rf /usr/share/bash-completion/completions/xray >/dev/null 2>&1
    rm -rf /etc/bash_completion.d/v2ray.bash >/dev/null 2>&1
    rm -rf /usr/local/bin/v2ray >/dev/null 2>&1
    rm -rf /etc/v2ray_util >/dev/null 2>&1
    crontab -l|sed '/SHELL=/d;/v2ray/d'|sed '/SHELL=/d;/xray/d' > crontab.txt
    crontab crontab.txt >/dev/null 2>&1
    rm -f crontab.txt >/dev/null 2>&1
    systemctl restart cron >/dev/null 2>&1
    sed -i '/v2ray/d' ~/.bashrc
    sed -i '/xray/d' ~/.bashrc
    source ~/.bashrc
    clear
    msg -bar
    print_center "V2RAY REMOVIDO!"
    log "V2Ray eliminado"
    enter
    return 1
}

v2ray_stream(){
    title "PROTOCOLOS V2RAY"
    echo -e "\033[1;37m"
    v2ray stream
    msg -bar
    read foo
}

port(){
    port=$(jq -r '.inbounds[0].port' $config)
    title "CONFIG PUERTO V2RAY"
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

alterid(){
    aid=$(jq -r '.inbounds[0].settings.clients[0].alterId' $config)
    title "CONFIG alterId V2RAY"
    print_center -azu "alterid actual: $(msg -ama "$aid")"
    back
    in_opcion "Nuevo alterid"
    opcion=$(echo "$opcion" | tr -d '[[:space:]]')
    tput cuu1 && tput dl1
    if [[ -z "$opcion" ]]; then
        msg -ne "ingresa un alterid"
        sleep 2
        return
    elif [[ ! $opcion =~ $numero ]]; then
        msg -ne "solo números"
        sleep 2
        return
    elif [[ "$opcion" = "0" ]]; then
        return
    fi
    mv $config $temp
    jq --argjson a "$opcion" '.inbounds[0].settings.clients[].alterId = $a' < $temp > $config
    chmod 777 $config
    rm $temp
    restart
}

n_v2ray(){
    title "CONFIGURACIÓN NATIVA V2RAY"
    echo -ne "\033[1;37m"
    v2ray
}

address(){
    add=$(jq -r '.inbounds[0].domain' $config) && [[ $add = null ]] && add=$(wget -qO- ipv4.icanhazip.com)
    title "CONFIG address V2RAY"
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
    title "CONFIG host V2RAY"
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
    title "CONFIG path V2RAY"
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
    title "RESTAURANDO AJUSTES V2RAY"
    user=$(jq -c '.inbounds[0].settings.clients' < $config)
    v2ray new
    jq 'del(.inbounds[0].streamSettings.kcpSettings[])' < $config > $temp
    rm $config
    jq '.inbounds[0].streamSettings += {"network":"ws","wsSettings":{"path": "/VPS-SN/","headers": {"Host": "ejemplo.com"}}}' < $temp > $config
    chmod 777 $config
    rm $temp
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
        echo -e "${W}              V2RAY MANAGER BY @SIN_NOMBRE22${N}"
        echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
        echo ""
        echo -e "${W}                     INSTALACIÓN${N}"
        echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
        echo -e "${R}[${Y}1${R}]${N}  ${C}INSTALAR V2RAY${N}              ${R}[${Y}0${R}]${N}  ${C}VOLVER${N}"
        echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
        echo ""
        echo -ne "${W}Selecciona una opción: ${G}"
        read -r opcion
        case "${opcion:-}" in
            1) ins_v2r; break ;;
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
    echo -e "${W}              V2RAY MANAGER BY @SIN_NOMBRE22${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo ""
    echo -e "${W}                       INSTALACIÓN${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${R}[${Y}1${R}]${N}  ${C}INSTALL/RE-REINSTALL V2RAY${N}  ${R}[${Y}2${R}]${N}  ${C}DESINSTALAR V2RAY${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${W}                   CONFIGURACIÓN BÁSICA${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${R}[${Y}3${R}]${N}  ${C}Configurar Puerto${N}"
    echo -e "${R}[${Y}4${R}]${N}  ${C}Configurar AlterId${N}"
    echo -e "${R}[${Y}5${R}]${N}  ${C}Configurar Address${N}"
    echo -e "${R}[${Y}6${R}]${N}  ${C}Configurar Host${N}"
    echo -e "${R}[${Y}7${R}]${N}  ${C}Configurar Path${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${W}                 CONFIGURACIÓN AVANZADA${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${R}[${Y}8${R}]${N}  ${C}Certificado SSL/TLS${N}         ${R}[${Y}9${R}]${N}  ${C}Protocolos V2Ray${N}"
    echo -e "${R}[${Y}10${R}]${N} ${C}Configuración Nativa${N}         ${R}[${Y}11${R}]${N} ${C}Restablecer Ajustes${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${R}[${Y}0${R}]${N}  ${C}VOLVER${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo ""
    echo -ne "${W}Selecciona una opción: ${G}"
    read -r opcion
    case "${opcion:-}" in
        1)ins_v2r;;
        2)removeV2Ray;;
        3)port;;
        4)alterid;;
        5)address;;
        6)host;;
        7)path;;
        8)v2ray_tls;;
        9)v2ray_stream;;
        10)n_v2ray;;
        11)reset;;
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
