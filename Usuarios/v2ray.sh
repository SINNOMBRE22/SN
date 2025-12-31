#!/bin/bash
set -euo pipefail

# =========================================================
# SinNombre - Autonomía V2Ray (Gestión de Usuarios Mejorada)
# =========================================================
# Mejoras: Unificación con Protocolos/v2ray.sh, validaciones robustas, manejo de errores, logs, y seguridad mejorada.

# ===== RUTAS BASE SN =====
SN_DIR="/etc/SN"
SN_USERS="/etc/SN/usuarios"
SN_INSTALL="/etc/SN/install"
SN_LOGS="/etc/SN/logs"  # Nueva: Para logs

mkdir -p "$SN_DIR" "$SN_USERS" "$SN_INSTALL" "$SN_LOGS"

# ===== RUTAS V2RAY =====
config="/etc/v2ray/config.json"
temp=$(mktemp)  # Mejor: Archivo temporal seguro
logfile="$SN_LOGS/v2ray_usuarios.log"

# ===== VALIDACIONES =====
tx_num='^[a-zA-Z0-9]+$'
numero='^[0-9]+$'

# ===== COLORES SINNOMBRE =====
R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
B='\033[0;34m'
M='\033[0;35m'
C='\033[0;36m'
W='\033[1;37m'
N='\033[0m'

# ===== MENSAJES =====
msg() {
  case "$1" in
    -bar)   echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}" ;;
    -verd)  echo -e "${G}$2${N}" ;;
    -verm|-verm2) echo -e "${R}$2${N}" ;;
    -ama)   echo -e "${Y}$2${N}" ;;
    -azu)   echo -e "${C}$2${N}" ;;
    -ne)    echo -ne "$2" ;;
    *)      echo -e "$*" ;;
  esac
}

# ===== LOGGING =====
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$logfile"
}

# ===== TITULO =====
title() {
  clear
  msg -bar
  echo -e "${W} $* ${N}"
  msg -bar
}

# ===== TEXTO EN LINEA =====
print_center() {
  msg "$1" "$2"
}

# ===== MENU =====
menu_func() {
  local i=1
  for opt in "$@"; do
    echo -e "${R}[${Y}${i}${R}]${N}  ${opt}"
    ((i++))
  done
}

# ===== VOLVER =====
back() {
  msg -bar
  echo -e "${R}[${Y}0${R}]${N}  ${C}VOLVER${N}"
  msg -bar
}

# ===== SELECCIÓN =====
selection_fun() {
  local max=$1
  local opt
  while true; do
    echo -ne "${W}Selecciona una opción: ${G}"
    read -r opt
    [[ "$opt" =~ ^[0-9]+$ && "$opt" -ge 0 && "$opt" -le "$max" ]] && {
      echo "$opt"
      return
    }
  done
}

# ===== INPUT TEXTO =====
in_opcion() {
  echo ""
  echo -ne "${W}$1: ${G}"
  read -r opcion
}

# ===== VALIDAR DEPENDENCIAS =====
for cmd in jq uuidgen date curl; do
  command -v "$cmd" &>/dev/null || {
    msg -verm2 "Falta dependencia: $cmd"
    exit 1
  }
done

# ===== VALIDAR CONFIG =====
[[ -f "$config" ]] || {
  msg -verm2 "No se encontró $config"
  exit 1
}

# ===== TRAP PARA LIMPIEZA =====
trap 'rm -f "$temp"; log "Script terminado"' EXIT

#============Fin Del Mod ===============
restart(){
  title "REINICIANDO V2RAY"
  if systemctl restart v2ray &>/dev/null && v2ray test &>/dev/null; then
    print_center -verd "V2Ray reiniciado exitosamente"
    log "V2Ray reiniciado"
    msg -bar
    sleep 3
  else
    print_center -verm2 "Error al reiniciar V2Ray"
    log "Error: Reinicio fallido"
    msg -bar
    sleep 3
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
  users=$(jq '.inbounds[0].settings.clients | length' "$config")
  for (( i = 0; i < $users; i++ )); do
    user=$(jq -r --argjson a "$i" '.inbounds[0].settings.clients[$a].email' "$config")
    fecha=$(jq -r --argjson a "$i" '.inbounds[0].settings.clients[$a].date' "$config")
    [[ "$user" = "null" ]] && continue

    seg_exp=$(date +%s --date="$fecha" 2>/dev/null) || {
      log "Error: Fecha inválida para usuario $user"
      continue
    }
    exp="$(( ($seg_exp - $seg) / 86400 ))"
    [[ "$exp" -lt "0" ]] && exp="EXP"

    list "$i" "$user" "$fecha" "$exp"
  done
}

col2(){
  msg -ne "$1" && msg -ama " $2"
}

vmess(){
  ps=$(jq -r '.inbounds[0].settings.clients['$1'].email' "$config") && [[ $ps = null ]] && ps="default"
  id=$(jq -r '.inbounds[0].settings.clients['$1'].id' "$config")
  aid=$(jq '.inbounds[0].settings.clients['$1'].alterId' "$config")
  add=$(jq -r '.inbounds[0].domain // empty' "$config")
  [[ -z "$add" ]] && add=$(curl -s ifconfig.me || echo "IP no disponible")
  host=$(jq -r '.inbounds[0].streamSettings.wsSettings.headers.Host // empty' "$config")
  net=$(jq -r '.inbounds[0].streamSettings.network' "$config")
  path=$(jq -r '.inbounds[0].streamSettings.wsSettings.path // empty' "$config")
  port=$(jq '.inbounds[0].port' "$config")
  tls=$(jq -r '.inbounds[0].streamSettings.security' "$config")

  title "DATOS DE USUARIO: $ps"
  col2 "Remarks:" "$ps"
  col2 "Address:" "$add"
  col2 "Port:" "$port"
  col2 "id:" "$id"
  col2 "alterId:" "$aid"
  col2 "security:" "none"
  col2 "network:" "$net"
  [[ -n "$host" ]] && col2 "Host/SNI:" "$host"
  [[ -n "$path" ]] && col2 "Path:" "$path"
  col2 "TLS:" "$tls"
  msg -bar
  var="{\"v\":\"2\",\"ps\":\"$ps\",\"add\":\"$add\",\"port\":$port,\"aid\":$aid,\"type\":\"none\",\"net\":\"$net\",\"path\":\"$path\",\"host\":\"$host\",\"id\":\"$id\",\"tls\":\"$tls\"}"
  msg -ama "vmess://$(echo "$var" | jq -r '. | @base64')"
  msg -bar
  read foo
}

newuser(){
  title "CREAR NUEVO USUARIO V2RAY"
  list_user
  back
  in_opcion "Nuevo Usuario"
  opcion=$(echo "$opcion" | tr -d '[[:space:]]')
  [[ "$opcion" = "0" ]] && return
  [[ -z "$opcion" ]] && {
    tput cuu1 && tput dl1
    msg -verm2 "No se puede ingresar campos vacíos..."
    sleep 2
    return
  }
  [[ ! "$opcion" =~ $tx_num ]] && {
    tput cuu1 && tput dl1
    msg -verm2 "Ingrese solo letras y números..."
    sleep 2
    return
  }
  [[ "${#opcion}" -lt "4" ]] && {
    tput cuu1 && tput dl1
    msg -verm2 "Nombre demasiado corto!"
    sleep 2
    return
  }
  [[ "$(jq -r '.inbounds[0].settings.clients[].email' "$config" | grep -q "$opcion")" ]] && {
    tput cuu1 && tput dl1
    msg -verm2 "Este nombre de usuario ya existe..."
    sleep 2
    return
  }
  email="$opcion"
  in_opcion "Días de duración (máx 365)"
  opcion=$(echo "$opcion" | tr -d '[[:space:]]')
  [[ "$opcion" = "0" ]] && return
  [[ ! "$opcion" =~ $numero || "$opcion" -gt 365 ]] && {
    tput cuu1 && tput dl1
    msg -verm2 "Ingrese solo números (1-365)"
    sleep 2
    return
  }

  dias=$(date '+%y-%m-%d' -d "+$opcion days")
  alterid=$(jq -r '.inbounds[0].settings.clients[0].alterId // 0' "$config")
  uuid=$(uuidgen)
  var="{\"alterId\":$alterid,\"id\":\"$uuid\",\"email\":\"$email\",\"date\":\"$dias\"}"

  users=$(jq '.inbounds[0].settings.clients | length' "$config")
  jq --argjson a "$users" --argjson b "$var" '.inbounds[0].settings.clients[$a] = $b' "$config" > "$temp" && mv "$temp" "$config"
  chmod 644 "$config"
  log "Usuario creado: $email"
  restart
  vmess "$users"
}

deluser(){
  title "ELIMINAR USUARIOS"
  list_user
  back
  in_opcion "Opción"
  opcion=$(echo "$opcion" | tr -d '[[:space:]]')
  [[ "$opcion" = "0" ]] && return
  [[ ! "$opcion" =~ $numero ]] && {
    tput cuu1 && tput dl1
    msg -verm2 "Ingrese solo números"
    sleep 2
    return
  }
  msg -ne "¿Confirmar eliminación de usuario $opcion? [S/N]: " && read conf
  [[ $conf != @(S|s) ]] && return
  jq --argjson a "$opcion" 'del(.inbounds[0].settings.clients[$a])' "$config" > "$temp" && mv "$temp" "$config"
  chmod 644 "$config"
  log "Usuario eliminado: índice $opcion"
  restart
}

datos(){
  title "DATOS DE USUARIOS"
  list_user
  back
  in_opcion "Opción"
  [[ "$opcion" =~ $numero ]] && vmess "$opcion"
}

respaldo(){
  title "COPIAS DE SEGURIDAD DE USUARIOS"
  menu_func "CREAR COPIA DE USUARIOS" "RESTAURAR COPIA DE USUARIO"
  back
  opcion=$(selection_fun 2)

  case $opcion in
    1)backup_file="$SN_USERS/User-V2ray_$(date +%Y%m%d_%H%M%S).json"
      jq '.inbounds[0].settings.clients' "$config" > "$backup_file"
      title "COPIA REALIZADA CON ÉXITO"
      msg -ne "Copia: " && msg -ama "$backup_file"
      log "Backup creado: $backup_file"
      msg -bar
      read foo;;
    2)backups=("$SN_USERS"/User-V2ray_*.json)
      [[ ${#backups[@]} -eq 0 ]] && {
        msg -verm2 "No hay copias de usuarios"
        sleep 3
        return
      }
      echo "Copias disponibles:"
      select backup in "${backups[@]}"; do
        [[ -n "$backup" ]] && break
      done
      var=$(cat "$backup")
      [[ -z "$var" ]] && {
        msg -verm2 "Copia vacía"
        sleep 3
        return
      }
      jq --argjson clients "$var" '.inbounds[0].settings.clients = $clients' "$config" > "$temp" && mv "$temp" "$config"
      chmod 644 "$config"
      title "COPIA RESTAURADA CON ÉXITO"
      log "Backup restaurado: $backup"
      sleep 2
      restart;;
    0)return;;
  esac
}

while :
do
  title "GESTIÓN DE USUARIOS V2RAY"
  menu_func "$(msg -verd "CREAR USUARIOS")" \
  "$(msg -verm2 "ELIMINAR USUARIOS")" \
  "BLOQUEAR USUARIOS $(msg -verm2 "(no disponible)")" \
  "$(msg -ama "VMESS DE USUARIOS")" \
  "RESPALDO DE SEGURIDAD" \
  "Ver logs de cambios"
  back
  opcion=$(selection_fun 6)
  case $opcion in
    1)newuser;;
    2)deluser;;
    3);;
    4)datos;;
    5)respaldo;;
    6)echo "Logs en $logfile:" && cat "$logfile" && read foo;;
    0)break;;
  esac
done
