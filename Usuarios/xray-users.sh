#!/bin/bash
set -euo pipefail

CONFIG="/etc/xray/config.json"
TMP="$(mktemp)"
LOGFILE="/var/log/xray/sn-users.log"
mkdir -p /var/log/xray

R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'; W='\033[1;37m'; N='\033[0m'

log(){ echo "$(date '+%F %T') - $*" >> "$LOGFILE"; }
pause(){ read -p "ENTER para continuar"; }
title(){ clear; echo -e "${R}══════════════════════════${N}\n${W} $1 ${N}\n${R}══════════════════════════${N}"; }
require_deps(){ command -v jq >/dev/null || { echo "jq no instalado"; exit 1; }; }

list_users() {
  title "USUARIOS XRAY"
  jq -r '
    def clients:
      .inbounds[]
      | select(.protocol=="vmess" or .protocol=="vless")
      | .settings.clients[]
      | .email as $e
      | .id as $id
      | (.expiry // .date // "∞") as $exp
      | (.blocked // false) as $b
      | {email:$e,id:$id,exp:$exp,blocked:$b}
    ;
    clients
    | to_entries[]
    | "\(.key)) \(.value.email) | exp: \(.value.exp) | blocked: \(.value.blocked)"
  ' "$CONFIG"
  pause
}

add_user() {
  title "CREAR USUARIO"
  read -p "Usuario: " user
  [[ -z $user ]] && return
  read -p "Días (0 = infinito): " days
  [[ ! $days =~ ^[0-9]+$ ]] && return
  read -p "Protocolo (vmess/vless): " proto
  proto=$(echo "$proto" | tr '[:upper:]' '[:lower:]')
  [[ "$proto" != "vmess" && "$proto" != "vless" ]] && { echo "proto inválido"; sleep 2; return; }

  exp="∞"
  [[ $days -gt 0 ]] && exp=$(date -d "+$days days" +%F)
  uuid=$(uuidgen)

  jq --arg p "$proto" --arg id "$uuid" --arg email "$user" --arg exp "$exp" '
    (.inbounds[] | select(.protocol==$p) | .settings.clients) +=
      [{id:$id, email:$email, expiry:$exp}]
  ' "$CONFIG" > "$TMP" && mv "$TMP" "$CONFIG"

  systemctl restart xray
  log "Usuario creado: $user ($proto)"
  show_link "$user" "$proto"
}

del_user() {
  title "ELIMINAR USUARIO"
  read -p "Usuario: " user
  [[ -z $user ]] && return
  jq --arg u "$user" '
    (.inbounds[] | select(.protocol=="vmess" or .protocol=="vless") | .settings.clients) |=
      map(select(.email!=$u))
  ' "$CONFIG" > "$TMP" && mv "$TMP" "$CONFIG"
  systemctl restart xray
  log "Usuario eliminado: $user"
}

renew_user() {
  title "RENOVAR USUARIO"
  read -p "Usuario: " user
  read -p "Días extra: " days
  [[ ! $days =~ ^[0-9]+$ ]] && return
  jq --arg u "$user" --arg d "$days" '
    (.inbounds[] | select(.protocol=="vmess" or .protocol=="vless") | .settings.clients) |=
      map(if .email==$u then
            (.expiry // .date) as $e
            | .expiry = ( if $e=="∞" then "∞" else
                ( (strptime("%Y-%m-%d") | mktime + (($d|tonumber)*86400)) | strftime("%Y-%m-%d") )
              end)
          else . end)
  ' "$CONFIG" > "$TMP" && mv "$TMP" "$CONFIG"
  systemctl restart xray
  log "Usuario renovado: $user (+$days d)"
}

block_user() {
  title "BLOQUEAR/DESBLOQUEAR"
  read -p "Usuario: " user
  read -p "Estado (on=bloquear / off=desbloquear): " st
  st=$(echo "$st" | tr '[:upper:]' '[:lower:]')
  [[ "$st" != "on" && "$st" != "off" ]] && return
  flag=$([[ "$st" == "on" ]] && echo true || echo false)
  jq --arg u "$user" --argjson f "$flag" '
    (.inbounds[] | select(.protocol=="vmess" or .protocol=="vless") | .settings.clients) |=
      map(if .email==$u then .blocked=$f else . end)
  ' "$CONFIG" > "$TMP" && mv "$TMP" "$CONFIG"
  systemctl restart xray
  log "Usuario $user bloqueado=$flag"
}

show_link() {
  user="$1"; proto="$2"
  c=$(jq -r --arg u "$user" --arg p "$proto" '
    .inbounds[] | select(.protocol==$p) | . as $ib |
    .settings.clients[] | select(.email==$u) |
    {id, email, expiry: (.expiry // .date // "∞"), port: $ib.port,
     net: $ib.streamSettings.network,
     host: ($ib.streamSettings.wsSettings.headers.Host // ""),
     path: ($ib.streamSettings.wsSettings.path // ""),
     security: ($ib.streamSettings.security // "none"),
     domain: ($ib.domain // "")
    }
  ' "$CONFIG")
  [[ -z "$c" || "$c" == "null" ]] && { echo "No encontrado"; sleep 2; return; }

  id=$(echo "$c" | jq -r .id)
  port=$(echo "$c" | jq -r .port)
  net=$(echo "$c" | jq -r .net)
  host=$(echo "$c" | jq -r .host)
  path=$(echo "$c" | jq -r .path)
  sec=$(echo "$c" | jq -r .security)
  add=$(echo "$c" | jq -r .domain)
  [[ -z "$add" || "$add" == "null" ]] && add=$(curl -s ipv4.icanhazip.com)

  if [[ "$proto" == "vmess" ]]; then
    json=$(jq -n \
      --arg v "2" --arg ps "$user" --arg add "$add" --arg id "$id" \
      --arg net "$net" --arg path "$path" --arg host "$host" --arg sec "$sec" \
      --argjson port "$port" \
      '{v:$v,ps:$ps,add:$add,port:$port,id:$id,aid:0,net:$net,type:"none",path:$path,host:$host,tls:$sec}')
    echo -e "\n${Y}VMESS:${N}"
    echo "vmess://$(echo "$json" | base64 -w 0)"
  else
    params="type=$net&security=$sec&encryption=none"
    [[ -n "$path" && "$path" != "null" ]] && params="$params&path=$path"
    [[ -n "$host" && "$host" != "null" ]] && params="$params&host=$host"
    link="vless://$id@$add:$port?$params#$user"
    echo -e "\n${Y}VLESS:${N}"
    echo "$link"
  end
  pause
}

menu() {
  while true; do
    title "XRAY USER MANAGER"
    echo -e "${Y}1${N}) Crear usuario"
    echo -e "${Y}2${N}) Eliminar usuario"
    echo -e "${Y}3${N}) Renovar usuario"
    echo -e "${Y}4${N}) Bloquear/Desbloquear"
    echo -e "${Y}5${N}) Listar usuarios"
    echo -e "${Y}6${N}) Mostrar link (vmess/vless)"
    echo -e "${Y}0${N}) Salir"
    read -p "> " op
    case "$op" in
      1)add_user;;
      2)del_user;;
      3)renew_user;;
      4)block_user;;
      5)list_users;;
      6)read -p "Usuario: " u; read -p "Protocolo (vmess/vless): " p; p=$(echo "$p"|tr '[:upper:]' '[:lower:]'); show_link "$u" "$p";;
      0)break;;
    esac
  done
}

require_deps
menu
