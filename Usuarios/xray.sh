#!/bin/bash
# =====================================================
# XRAY USER MANAGER - SN
# Compatible XRAY CORE (VMESS)
# =====================================================

CONFIG="/etc/xray/config.json"
LOGFILE="/var/log/xray/sn-users.log"
TMP=$(mktemp)

mkdir -p /etc/SN/usuarios /var/log/xray

# ===== COLORES =====
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'
C='\033[0;36m'; W='\033[1;37m'; N='\033[0m'

# ===== LOG =====
log(){ echo "$(date '+%F %T') - $*" >> "$LOGFILE"; }

# ===== CHECK =====
command -v jq >/dev/null || { echo "jq no instalado"; exit 1; }
[[ ! -f $CONFIG ]] && { echo "config.json no existe"; exit 1; }

# ===== FUNCIONES =====
restart(){
  systemctl restart xray && log "XRAY reiniciado"
}

title(){
  clear
  echo -e "${R}══════════════════════════${N}"
  echo -e "${W} $1 ${N}"
  echo -e "${R}══════════════════════════${N}"
}

pause(){ read -p "ENTER para continuar"; }

# ===== LISTAR =====
list_users(){
  title "USUARIOS XRAY"
  jq -r '.inbounds[0].settings.clients[]? |
  "\(.email) | exp: \(.expiry // "∞") | id: \(.id)"' "$CONFIG"
  pause
}

# ===== CREAR =====
add_user(){
  title "CREAR USUARIO XRAY"
  read -p "Usuario: " user
  [[ -z $user ]] && return

  if jq -e ".inbounds[0].settings.clients[]?|select(.email==\"$user\")" "$CONFIG" >/dev/null; then
    echo "Usuario ya existe"; sleep 2; return
  fi

  read -p "Dias (0 = infinito): " days
  [[ ! $days =~ ^[0-9]+$ ]] && return

  uuid=$(uuidgen)
  [[ $days -gt 0 ]] && exp=$(date -d "+$days days" +%F) || exp="∞"

  client=$(jq -n \
    --arg id "$uuid" \
    --arg email "$user" \
    --arg expiry "$exp" \
    '{id:$id,email:$email,expiry:$expiry}')

  jq ".inbounds[0].settings.clients += [$client]" "$CONFIG" > "$TMP" && mv "$TMP" "$CONFIG"

  restart
  log "Usuario creado: $user"
  show_vmess "$user"
}

# ===== ELIMINAR =====
del_user(){
  title "ELIMINAR USUARIO"
  read -p "Usuario: " user
  [[ -z $user ]] && return

  jq ".inbounds[0].settings.clients |= map(select(.email!=\"$user\"))" \
    "$CONFIG" > "$TMP" && mv "$TMP" "$CONFIG"

  restart
  log "Usuario eliminado: $user"
}

# ===== RENOVAR =====
renew_user(){
  title "RENOVAR USUARIO"
  read -p "Usuario: " user
  read -p "Dias extra: " days
  [[ ! $days =~ ^[0-9]+$ ]] && return

  jq --arg u "$user" --arg d "$days" '
  .inbounds[0].settings.clients |=
  map(if .email==$u then
    .expiry=(.expiry=="∞" ? "∞" :
      ( (strptime("%Y-%m-%d")|mktime + ($d|tonumber*86400)) | strftime("%Y-%m-%d") ))
  else . end)' "$CONFIG" > "$TMP" && mv "$TMP" "$CONFIG"

  restart
  log "Usuario renovado: $user"
}

# ===== VMESS =====
show_vmess(){
  user="$1"
  c=$(jq -r ".inbounds[0].settings.clients[]|select(.email==\"$user\")" "$CONFIG")
  [[ -z $c ]] && return

  id=$(echo "$c"|jq -r .id)
  port=$(jq -r '.inbounds[0].port' "$CONFIG")
  net=$(jq -r '.inbounds[0].streamSettings.network' "$CONFIG")
  host=$(jq -r '.inbounds[0].streamSettings.wsSettings.headers.Host // ""' "$CONFIG")
  path=$(jq -r '.inbounds[0].streamSettings.wsSettings.path // ""' "$CONFIG")
  tls=$(jq -r '.inbounds[0].streamSettings.security // "none"' "$CONFIG")
  add=$(curl -s ipv4.icanhazip.com)

  json=$(jq -n \
    --arg ps "$user" --arg add "$add" --arg id "$id" \
    --arg net "$net" --arg path "$path" --arg host "$host" --arg tls "$tls" \
    --argjson port "$port" \
    '{v:"2",ps:$ps,add:$add,port:$port,id:$id,aid:0,net:$net,type:"none",path:$path,host:$host,tls:$tls}')

  echo -e "\n${Y}VMESS:${N}"
  echo "vmess://$(echo "$json" | base64 -w 0)"
  pause
}

# ===== MENU =====
while :
do
  title "XRAY USER MANAGER - SN"
  echo -e "${Y}1${N}) Crear usuario"
  echo -e "${Y}2${N}) Eliminar usuario"
  echo -e "${Y}3${N}) Renovar usuario"
  echo -e "${Y}4${N}) Listar usuarios"
  echo -e "${Y}0${N}) Salir"
  read -p "> " op

  case $op in
    1)add_user;;
    2)del_user;;
    3)renew_user;;
    4)list_users;;
    0)exit;;
  esac
done
