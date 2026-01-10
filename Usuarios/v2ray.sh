#!/bin/bash

# =====================================================
# GESTIÓN DE USUARIOS V2RAY - SINNOMBRE (Versión Completa Mejorada)
# Versión: 1.2 - Bloqueo/renovación, monitoreo por UUID, logging, etc.
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
tx_num='^[a-zA-Z0-9_]+$'

# ===== COLORES =====
R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
B='\033[0;34m'
C='\033[0;36m'
W='\033[1;37m'
N='\033[0m'

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
    command -v jq >/dev/null 2>&1 || { msg -verm2 "jq no instalado."; exit 1; }
    [[ -f "$config" ]] || { msg -verm2 "Config no encontrado."; return 1; }
    return 0
}

# ===== LIMPIAR PANTALLA =====
clear_screen() { clear; }

# ===== PAUSA =====
pause() {
  echo ""
  read -r -p "Presiona Enter para continuar..."
}

restart(){
    title "REINICIANDO V2RAY"
    if v2ray restart 2>&1 | grep -q "success"; then
        print_center -verd "v2ray restart success!"
        msg -bar
        sleep 3
        log "Restart exitoso"
    else
        print_center -verm2 "v2ray restart fail!"
        msg -bar
        sleep 3
        log "Restart fallido"
        return
    fi
}

list(){
    name=$(printf '%-25s' "$2")
    fecha=$(printf '%-10s' "$3")
    if [[ "$4" = "EXP" ]]; then
        dias=$(msg -verm2 "[$4]")
    else
        dias=$(msg -verd "[$4]")
    fi
    echo -e "$(msg -verd " [$1]") $(msg -verm2 ">") $(msg -azu "$name") $(msg -verm2 "$fecha") $dias"
}

userDat(){
    n=$(printf '%-5s' 'N°')
    u=$(printf '%-25s' 'Usuarios')
    f=$(printf '%-10s' 'fech exp')
    msg -azu "  $n $u $f dias"
    msg -bar
}

list_user(){
    unset seg
    seg=$(date +%s)
    userDat
    users=$(jq '.inbounds[].settings.clients | length' $config)
    for (( i = 0; i < $users; i++ )); do
        user=$(jq -r --argjson a "$i" '.inbounds[].settings.clients[$a].email' < $config)
        fecha=$(jq -r --argjson a "$i" '.inbounds[].settings.clients[$a].date' < $config)
        [[ "$user" = "null" ]] && continue
        blocked=$(jq -r --argjson a "$i" '.inbounds[].settings.clients[$a].blocked // "false"' < $config)
        [[ "$blocked" = "true" ]] && continue
        seg_exp=$(date +%s --date="$fecha")
        exp="$(($(($seg_exp - $seg)) / 86400))"
        [[ "$exp" -lt "0" ]] && exp="EXP"
        list "$i" "$user" "$fecha" "$exp"
    done
}

col2(){
    msg -ne "$1" && msg -ama " $2"
}

vmess(){
    ps=$(jq -r .inbounds[].settings.clients[$1].email $config) && [[ $ps = null ]] && ps="default"
    id=$(jq -r .inbounds[].settings.clients[$1].id $config)
    aid=$(jq .inbounds[].settings.clients[$1].alterId $config)
    add=$(jq -r .inbounds[].domain $config) && [[ $add = null ]] && add=$(wget -qO- ipv4.icanhazip.com)
    host=$(jq -r .inbounds[].streamSettings.wsSettings.headers.Host $config) && [[ $host = null ]] && host=''
    net=$(jq -r .inbounds[].streamSettings.network $config)
    path=$(jq -r .inbounds[].streamSettings.wsSettings.path $config) && [[ $path = null ]] && path=''
    port=$(jq .inbounds[].port $config)
    tls=$(jq -r .inbounds[].streamSettings.security $config)

    title "DATOS DE USUARIO: $ps"
    col2 "Remarks:" "$ps"
    col2 "Address:" "$add"
    col2 "Port:" "$port"
    col2 "id:" "$id"
    col2 "alterId:" "$aid"
    col2 "security:" "none"
    col2 "network:" "$net"
    col2 "Head Type:" "none"
    [[ ! $host = '' ]] && col2 "Host/SNI:" "$host"
    [[ ! $path = '' ]] && col2 "Path:" "$path"
    col2 "TLS:" "$tls"
    msg -bar
    var="{\"v\":\"2\",\"ps\":\"$ps\",\"add\":\"$add\",\"port\":$port,\"aid\":$aid,\"type\":\"none\",\"net\":\"$net\",\"path\":\"$path\",\"host\":\"$host\",\"id\":\"$id\",\"tls\":\"$tls\"}"
    msg -ama "vmess://$(echo "$var"|jq -r '.|@base64')"
    msg -bar
    read foo
}

newuser(){
    title "CREAR NUEVO USUARIO V2RAY"
    list_user
    back
    in_opcion "Nuevo Usuario"
    opcion=$(echo "$opcion" | tr -d '[[:space:]]')
    if [[ "$opcion" = "0" ]]; then
        return
    elif [[ -z "$opcion" ]]; then
        tput cuu1 && tput dl1
        msg -verm2 "no vacíos"
        sleep 2
        return
    elif [[ ! "$opcion" =~ $tx_num ]]; then
        tput cuu1 && tput dl1
        msg -verm2 "solo letras/números"
        sleep 2
        return
    elif [[ "${#opcion}" -lt "4" ]]; then
        tput cuu1 && tput dl1
        msg -verm2 "muy corto"
        sleep 2
        return
    elif [[ "$(jq -r '.inbounds[].settings.clients[].email' < $config|grep "$opcion")" ]]; then
        tput cuu1 && tput dl1
        msg -verm2 "ya existe"
        sleep 2
        return
    fi
    email="$opcion"
    in_opcion "Dias de duracion"
    opcion=$(echo "$opcion" | tr -d '[[:space:]]')
    if [[ "$opcion" = "0" ]]; then
        return
    elif [[ ! "$opcion" =~ $numero ]]; then
        tput cuu1 && tput dl1
        msg -verm2 "solo números"
        sleep 2
        return
    fi

    dias=$(date '+%y-%m-%d' -d " +$opcion days")
    alterid=$(jq -r '.inbounds[].settings.clients[0].alterId' < $config)
    uuid=$(uuidgen)
    var="{\"alterId\":"$alterid",\"id\":\"$uuid\",\"email\":\"$email\",\"date\":\"$dias\"}"

    mv $config $temp
    jq --argjson a "$users" --argjson b "$var" '.inbounds[].settings.clients[$a] += $b' < $temp > $config
    chmod 777 $config
    rm -rf $temp
    restart
    vmess "$users"
}

deluser(){
    title "ELIMINAR USUARIOS"
    list_user
    back
    in_opcion "Opcion"
    opcion=$(echo "$opcion" | tr -d '[[:space:]]')
    if [[ "$opcion" = "0" ]]; then
        return
    elif [[ ! "$opcion" =~ $numero ]]; then
        tput cuu1 && tput dl1
        msg -verm2 "solo números"
        sleep 2
        return
    fi
    read -p "Confirmar eliminación [y/N]: " confirm
    [[ "$confirm" =~ ^[yY]$ ]] || return
    mv $config $temp
    jq --argjson a "$opcion" 'del(.inbounds[].settings.clients[$a])' < $temp > $config
    chmod 777 $config
    rm -rf $temp
    restart
}

datos(){
    title "DATOS DE USUARIOS"
    list_user
    back
    in_opcion "Opcion"
    vmess "$opcion"
}

respaldo(){
    title "COPIAS DE SEGURIDAD DE USUARIOS"
    menu_func "CREAR COPIA DE USUARIOS" "RESTAURAR COPIA DE USUARIO"
    back
    opcion=$(selection_fun 2)

    case $opcion in
        1)rm -rf /root/User-V2ray.txt
        jq '.inbounds[].settings.clients' < $config > /root/User-V2ray.txt
        title "COPIA REALIZADO CON EXITO"
        msg -ne " Copia: " && msg -ama "/root/User-V2ray.txt"
        msg -bar
        read foo
        log "Copia creada";;
        2)[[ ! -e "/root/User-V2ray.txt" ]] && msg -verm2 "no hay copia" && sleep 3 && return
        var=$(cat /root/User-V2ray.txt)
        [[ -z "$var" ]] && msg -verm2 "copia vacia" && sleep 3 && return
        read -p "Confirmar restauración [y/N]: " confirm
        [[ "$confirm" =~ ^[yY]$ ]] || return
        mv $config $temp
        jq --argjson a "$var" '.inbounds[].settings += {clients:$a}' < $temp > $config
        chmod 777 $config
        rm -rf $temp
        title "COPIA RESTAURADA"
        sleep 2
        restart
        log "Copia restaurada";;
        0)return;;
    esac
}

blockuser(){
    title "BLOQUEAR USUARIOS"
    list_user
    back
    in_opcion "Usuario a bloquear"
    opcion=$(echo "$opcion" | tr -d '[[:space:]]')
    if [[ "$opcion" = "0" ]]; then return; fi
    mv $config $temp
    jq --argjson a "$opcion" '.inbounds[].settings.clients[$a] += {"blocked": true}' < $temp > $config
    chmod 777 $config
    rm $temp
    restart
    log "Usuario bloqueado: $opcion"
}

renewuser(){
    title "RENOVAR USUARIO"
    list_user
    back
    in_opcion "Usuario a renovar"
    user_opt=$(echo "$opcion" | tr -d '[[:space:]]')
    if [[ "$user_opt" = "0" ]]; then return; fi
    in_opcion "Dias adicionales"
    dias_opt=$(echo "$opcion" | tr -d '[[:space:]]')
    [[ "$dias_opt" =~ $numero ]] || { msg -verm2 "solo números"; return; }
    current_date=$(jq -r --argjson a "$user_opt" '.inbounds[].settings.clients[$a].date' < $config)
    new_date=$(date '+%y-%m-%d' -d "$current_date +$dias_opt days")
    mv $config $temp
    jq --argjson a "$user_opt" --arg b "$new_date" '.inbounds[].settings.clients[$a].date = $b' < $temp > $config
    chmod 777 $config
    rm $temp
    restart
    log "Usuario renovado: $user_opt"
}

monitor(){
  clear
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
  echo -e "${Y}           📡 MONITOR DE USUARIOS V2RAY 📡${N}"
  echo -e "${R}────────────────────────── / / / ──────────────────────────${N}"

  # ENCABEZADO
  printf " %-14s %-12s %-16s %-10s\n" \
  "USUARIO" "ESTADO" "CONEXIONES" "TIEMPO"

  echo -e "${R}────────────────────────── / / / ──────────────────────────${N}"

  since=$(date -d '1 hour ago' +%s)
  users_count=$(jq '.inbounds[].settings.clients | length' $config)
  for (( i = 0; i < users_count; i++ )); do
    user=$(jq -r --argjson a "$i" '.inbounds[].settings.clients[$a].email' < $config)
    [[ "$user" = "null" ]] && continue
    blocked=$(jq -r --argjson a "$i" '.inbounds[].settings.clients[$a].blocked // "false"' < $config)
    [[ "$blocked" = "true" ]] && continue

    uuid=$(jq -r --argjson a "$i" '.inbounds[].settings.clients[$a].id' < $config)
    conex=$(grep "$uuid" /var/log/v2ray/access.log 2>/dev/null | awk -v since="$since" '$1 >= since' | wc -l)
    [[ -z "$conex" ]] && conex=0

    [[ $conex -gt 0 ]] && estado="ONLINE" || estado="OFFLINE"
    conex_display="$conex/∞"

    if [[ "$estado" = "ONLINE" ]]; then
      pid=$(pgrep -f v2ray | head -1)
      timerr=$(ps -o etime= -p "$pid" 2>/dev/null | sed 's/^ *//' | head -1)
      [[ -z "$timerr" || ${#timerr} -lt 8 ]] && timerr="00:00:00"
    else
      timerr="00:00:00"
    fi

    userf=$(printf '%-14s' "$user")
    estado_txt=$(printf '%-12s' "$estado")
    conf=$(printf '%-16s' "$conex_display")
    timef=$(printf '%-10s' "$timerr")

    [[ "$estado" = "OFFLINE" ]] && estado_color=$R || estado_color=$G

    printf " ${Y}%-14s${N} ${estado_color}%-12s${N} ${G}%-16s${N} ${Y}%-10s${N}\n" \
    "$userf" "$estado_txt" "$conf" "$timef"
    echo -e "${R}─────────────────────────── / / / ──────────────────────────${N}"
  done

  echo -e "${Y}            ►► Presione ENTER para continuar ◄◄${N}"
  read
}

# ===== AUTO-LIMPIEZA =====
trap 'rm -f "$temp"' EXIT

# ===== INICIO =====
check_deps || exit 1

while :
do
    clear_screen
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${W}              GESTION DE USUARIOS V2RAY${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo ""
    echo -e "${W}                     MENU USUARIOS${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${R}[${Y}1${R}]${N}  ${C}CREAR USUARIOS${N}"
    echo -e "${R}[${Y}2${R}]${N}  ${C}ELIMINAR USUARIOS${N}"
    echo -e "${R}[${Y}3${R}]${N}  ${C}VMESS DE USUARIOS${N}"
    echo -e "${R}[${Y}4${R}]${N}  ${C}RESPALDO DE SEGURIDAD${N}"
    echo -e "${R}[${Y}5${R}]${N}  ${C}BLOQUEAR USUARIOS${N}"
    echo -e "${R}[${Y}6${R}]${N}  ${C}RENOVAR USUARIOS${N}"
    echo -e "${R}[${Y}7${R}]${N}  ${C}MONITOREAR USUARIOS${N}"
    echo -e "${R}[${Y}0${R}]${N}  ${C}VOLVER${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo ""
    echo -ne "${W}Selecciona una opción: ${G}"
    read -r opcion

    case "${opcion:-}" in
        1)newuser;;
        2)deluser;;
        3)datos;;
        4)respaldo;;
        5)blockuser;;
        6)renewuser;;
        7)monitor;;
        0)break;;
        *)
            clear_screen
            echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
            echo -e "${B}                   OPCIÓN INVÁLIDA${N}"
            echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
            sleep 2
            ;;
    esac
done
exit 0
