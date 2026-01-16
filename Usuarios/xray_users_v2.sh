#!/bin/bash

# =====================================================
# GESTIÓN DE USUARIOS XRAY - SINNOMBRE (Versión v2 con VLESS)
# Versión: 2.0 - Bloqueo/renovación, monitoreo por UUID, logging, VLESS
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
    systemctl is-active --quiet xray || { msg -verm2 "xray no corriendo."; return 1; }
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
    title "REINICIANDO XRAY"
    systemctl restart xray
    if systemctl is-active --quiet xray; then
        print_center -verd "xray restart success!"
        msg -bar
        sleep 3
        log "Restart exitoso"
    else
        print_center -verm2 "xray restart fail!"
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
    users=$(jq '.inbounds[0].settings.clients | length' $config)
    for (( i = 0; i < $users; i++ )); do
        user=$(jq -r --argjson a "$i" '.inbounds[0].settings.clients[$a].email' < $config)
        [[ "$user" = "null" ]] && continue
        blocked=$(jq -r --argjson a "$i" '.inbounds[0].settings.clients[$a].blocked // "false"' < $config)
        [[ "$blocked" = "true" ]] && continue
        fecha=$(jq -r --argjson a "$i" '.inbounds[0].settings.clients[$a].date' < $config)
        seg_exp=$(date +%s --date="$fecha")
        exp="$(($(($seg_exp - $seg)) / 86400))"
        [[ "$exp" -lt "0" ]] && exp="EXP"
        list "$i" "$user" "$fecha" "$exp"
    done
}

vless(){
    ps=$(jq -r .inbounds[0].settings.clients[$1].email $config) && [[ $ps = null ]] && ps="default"
    id=$(jq -r .inbounds[0].settings.clients[$1].id $config)
    flow=$(jq -r .inbounds[0].settings.clients[$1].flow $config)
    add=$(jq -r .inbounds[0].domain $config) && [[ $add = null ]] && add=$(wget -qO- ipv4.icanhazip.com)
    host=$(jq -r .inbounds[0].streamSettings.wsSettings.headers.Host $config) && [[ $host = null ]] && host=''
    net=$(jq -r .inbounds[0].streamSettings.network $config)
    path=$(jq -r .inbounds[0].streamSettings.wsSettings.path $config) && [[ $path = null ]] && path=''
    port=$(jq .inbounds[0].port $config)
    security=$(jq -r .inbounds[0].streamSettings.security $config)

    title "DATOS DE USUARIO: $ps"
    col2 "Remarks:" "$ps"
    col2 "Address:" "$add"
    col2 "Port:" "$port"
    col2 "id:" "$id"
    col2 "flow:" "$flow"
    col2 "security:" "$security"
    col2 "network:" "$net"
    [[ ! $host = '' ]] && col2 "Host/SNI:" "$host"
    [[ ! $path = '' ]] && col2 "Path:" "$path"
    msg -bar
    var="{\"v\":\"2\",\"ps\":\"$ps\",\"add\":\"$add\",\"port\":$port,\"id\":\"$id\",\"flow\":\"$flow\",\"type\":\"\",\"net\":\"$net\",\"path\":\"$path\",\"host\":\"$host\",\"tls\":\"$security\"}"
    msg -ama "vless://$(echo "$var"|jq -r '.|@base64')"
    msg -bar
    read foo
}

newuser(){
    title "CREAR NUEVO USUARIO XRAY"
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
    elif [[ "$(jq -r '.inbounds[0].settings.clients[].email' < $config|grep "$opcion")" ]]; then
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
    uuid=$(uuidgen)
    flow="xtls-rprx-vision"
    var="{\"flow\":\"$flow\",\"id\":\"$uuid\",\"email\":\"$email\",\"date\":\"$dias\"}"

    mv $config $temp
    jq --argjson a "$users" --argjson b "$var" '.inbounds[0].settings.clients[$a] += $b' < $temp > $config
    chmod 777 $config
    rm -rf $temp
    restart
    vless "$users"
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
    jq --argjson a "$opcion" 'del(.inbounds[0].settings.clients[$a])' < $temp > $config
    chmod 777 $config
    rm -rf $temp
    restart
}

datos(){
    title "DATOS DE USUARIOS"
    list_user
    back
    in_opcion "Opcion"
    vless "$opcion"
}

respaldo(){
    title "COPIAS DE SEGURIDAD DE USUARIOS"
    menu_func "CREAR COPIA DE USUARIOS" "RESTAURAR COPIA DE USUARIO"
    back
    opcion=$(selection_fun 2)

    case $opcion in
        1)rm -rf /root/User-Xray.txt
        jq '.inbounds[0].settings.clients' < $config > /root/User-Xray.txt
        title "COPIA REALIZADO CON EXITO"
        msg -ne " Copia: " && msg -ama "/root/User-Xray.txt"
        msg -bar
        read foo
        log "Copia creada";;
        2)[[ ! -e "/root/User-Xray.txt" ]] && msg -verm2 "no hay copia" && sleep 3 && return
        var=$(cat /root/User-Xray.txt)
        [[ -z "$var" ]] && msg -verm2 "copia vacia" && sleep 3 && return
        read -p "Confirmar restauración [y/N]: " confirm
        [[ "$confirm" =~ ^[yY]$ ]] || return
        mv $config $temp
        jq --argjson a "$var" '.inbounds[0].settings += {clients:$a}' < $temp > $config
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
    jq --argjson a "$opcion" '.inbounds[0].settings.clients[$a] += {"blocked": true}' < $temp > $config
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
    current_date=$(jq -r --argjson a "$user_opt" '.inbounds[0].settings.clients[$a].date' < $config)
    new_date=$(date '+%y-%m-%d' -d "$current_date +$dias_opt days")
    mv $config $temp
    jq --argjson a "$user_opt" --arg b "$new_date" '.inbounds[0].settings.clients[$a].date = $b' < $temp > $config
    chmod 777 $config
    rm $temp
    restart
    log "Usuario renovado: $user_opt"
}

monitor(){
  clear
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
  echo -e "${Y}           📡 MONITOR DE USUARIOS XRAY 📡${N}"
  echo -e "${R}────────────────────────── / / / ──────────────────────────${N}"

  # ENCABEZADO
  printf " %-14s %-12s %-16s %-10s\n" \
  "USUARIO" "ESTADO" "CONEXIONES" "TIEMPO"

  echo -e "${R}────────────────────────── / / / ──────────────────────────${N}"

  since=$(date -d '1 hour ago' +%s)
  users_count=$(jq '.inbounds[0].settings.clients | length' $config)
  for (( i = 0; i < users_count; i++ )); do
    user=$(jq -r --argjson a "$i" '.inbounds[0].settings.clients[$a].email' < $config)
    [[ "$user" = "null" ]] && continue
    blocked=$(jq -r --argjson a "$i" '.inbounds[0].settings.clients[$a].blocked // "false"' < $config)
    [[ "$blocked" = "true" ]] && continue

    uuid=$(jq -r --argjson a "$i" '.inbounds[0].settings.clients[$a].id' < $config)
    conex=$(grep "$uuid" /var/log/xray/access.log 2>/dev/null | awk -v since="$since" '$1 >= since' | wc -l)
    [[ -z "$conex" ]] && conex=0

    [[ $conex -gt 0 ]] && estado="ONLINE" || estado="OFFLINE"
    conex_display="$conex/∞"

    if [[ "$estado" = "ONLINE" ]]; then
      pid=$(pgrep -f xray | head -1)
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
    echo -e "${W}              GESTION DE USUARIOS XRAY${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo ""
    echo -e "${W}                     MENU USUARIOS${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${R}[${Y}1${R}]${N}  ${C}CREAR USUARIOS${N}"
    echo -e "${R}[${Y}2${R}]${N}  ${C}ELIMINAR USUARIOS${N}"
    echo -e "${R}[${Y}3${R}]${N}  ${C}VLESS DE USUARIOS${N}"
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
