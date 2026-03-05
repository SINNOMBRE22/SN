#!/bin/bash
# =========================================================
# SinNombre v2.0 - GESTIÓN DE USUARIOS V2RAY (VMess + VLESS)
# Archivo: SN/Usuarios/v2ray.sh
#
# Ambos protocolos en el mismo config.json:
# - inbound tag "vless-in" → protocolo vless
# - inbound tag "vmess-in" → protocolo vmess
# Cada uno con sus propios clientes
# UUID personalizado o auto-generado
# =========================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── Cargar colores desde lib ────────────────────────────
LIB_COLORES="$ROOT_DIR/lib/colores.sh"
if [[ -f "$LIB_COLORES" ]]; then
  source "$LIB_COLORES"
else
  R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; B='\033[0;34m'
  C='\033[0;36m'; W='\033[1;37m'; N='\033[0m'; D='\033[2m'; BOLD='\033[1m'
  hr()  { echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"; }
  sep() { echo -e "${R}──────────────────────────────────────────────────────────${N}"; }
  pause(){ echo ""; read -r -p "Presiona Enter para continuar..."; }
fi

# ── Rutas ───────────────────────────────────────────────
LOGFILE="/var/log/v2ray_manager.log"
XRAY_CONFIG="/usr/local/etc/xray/config.json"
V2RAY_CONFIG="/etc/v2ray/config.json"
config=""
numero='^[0-9]+$'
tx_num='^[a-zA-Z0-9_]+$'

mkdir -p "$(dirname "$LOGFILE")" 2>/dev/null || true

# =========================================================
#  ANIMACIONES
# =========================================================

spinner() {
  local pid="$1"
  local msg="${2:-Procesando...}"
  local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
  local i=0
  tput civis 2>/dev/null || true
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  ${C}${frames[$i]}${N} ${W}%s${N}" "$msg"
    i=$(( (i + 1) % ${#frames[@]} ))
    sleep 0.1
  done
  wait "$pid" 2>/dev/null
  local exit_code=$?
  if [[ $exit_code -eq 0 ]]; then
    printf "\r  ${G}✓${N} ${W}%-50s${N}\n" "$msg"
  else
    printf "\r  ${R}✗${N} ${W}%-50s${N}\n" "$msg"
  fi
  tput cnorm 2>/dev/null || true
  return $exit_code
}

# =========================================================
#  UTILIDADES
# =========================================================

log_msg() {
  echo "$(date '+%Y-%m-%d %H:%M:%S'): $*" >> "$LOGFILE"
}

detect_config() {
  if [[ -f "$XRAY_CONFIG" ]]; then
    config="$XRAY_CONFIG"
  elif [[ -f "$V2RAY_CONFIG" ]]; then
    config="$V2RAY_CONFIG"
  else
    config=""
  fi
}

check_deps() {
  command -v jq >/dev/null 2>&1 || { echo -e "  ${R}✗${N} ${W}jq no instalado${N}"; exit 1; }
  detect_config
  [[ -n "$config" ]] || { echo -e "  ${R}✗${N} ${W}Config no encontrado${N}"; exit 1; }
}

detect_service() {
  if systemctl list-unit-files 2>/dev/null | grep -q '^xray.service'; then
    echo "xray"
  elif systemctl list-unit-files 2>/dev/null | grep -q '^v2ray.service'; then
    echo "v2ray"
  else
    echo ""
  fi
}

service_restart() {
  local svc
  svc="$(detect_service)"
  [[ -z "$svc" ]] && return 1
  (
    systemctl restart "$svc" >/dev/null 2>&1 || true
    sleep 1
  ) &
  spinner $! "Reiniciando ${svc}..."
}

get_ip() {
  curl -fsS --max-time 2 ifconfig.me 2>/dev/null || echo "TU_IP"
}

get_port() {
  jq -r '.inbounds[0].port // "443"' "$config" 2>/dev/null || echo "443"
}

# ── Contar usuarios por protocolo ───────────────────────

get_vless_count() {
  jq '[.inbounds[] | select(.protocol=="vless") | .settings.clients | length] | add // 0' "$config" 2>/dev/null || echo "0"
}

get_vmess_count() {
  jq '[.inbounds[] | select(.protocol=="vmess") | .settings.clients | length] | add // 0' "$config" 2>/dev/null || echo "0"
}

# ── Obtener índice del inbound ──────────────────────────

get_inbound_index() {
  local proto="$1"  # vless o vmess
  jq --arg p "$proto" '[.inbounds[] | .protocol] | to_entries[] | select(.value==$p) | .key' "$config" 2>/dev/null | head -1
}

# =========================================================
#  LISTAR USUARIOS (ambos protocolos)
# =========================================================

list_all_users() {
  local seg
  seg=$(date +%s)

  echo -e "  ${W}${BOLD}── USUARIOS VLESS ──${N}"
  sep
  local vless_idx
  vless_idx="$(get_inbound_index vless)"

  if [[ -n "$vless_idx" ]]; then
    local vless_count
    vless_count=$(jq --argjson idx "$vless_idx" '.inbounds[$idx].settings.clients | length' "$config" 2>/dev/null || echo "0")

    if [[ "$vless_count" -eq 0 ]]; then
      echo -e "  ${D}(sin usuarios)${N}"
    else
      printf "  ${D}%-4s %-18s %-12s %-6s %-6s${N}\n" "N°" "Usuario" "Expira" "Días" "Estado"
      for (( i = 0; i < vless_count; i++ )); do
        local user fecha blocked exp status_txt status_color
        user=$(jq -r --argjson idx "$vless_idx" --argjson a "$i" '.inbounds[$idx].settings.clients[$a].email // "sin-nombre"' "$config")
        fecha=$(jq -r --argjson idx "$vless_idx" --argjson a "$i" '.inbounds[$idx].settings.clients[$a].date // "∞"' "$config")
        blocked=$(jq -r --argjson idx "$vless_idx" --argjson a "$i" '.inbounds[$idx].settings.clients[$a].blocked // "false"' "$config")

        if [[ "$blocked" == "true" ]]; then
          status_txt="BLOQ"; status_color="$R"; exp="-"
        elif [[ "$fecha" != "∞" && "$fecha" != "null" && "$fecha" != "N/A" ]]; then
          local seg_exp
          seg_exp=$(date +%s --date="$fecha" 2>/dev/null || echo "0")
          exp="$(( (seg_exp - seg) / 86400 ))"
          (( exp < 0 )) && { status_txt="EXP"; status_color="$R"; exp="0"; } || { status_txt="OK"; status_color="$G"; }
        else
          exp="∞"; status_txt="OK"; status_color="$G"
        fi

        printf "  ${G}%-4s${N} ${C}%-18s${N} ${Y}%-12s${N} ${W}%-6s${N} ${status_color}%-6s${N}\n" \
          "[$i]" "$user" "$fecha" "$exp" "$status_txt"
      done
    fi
  else
    echo -e "  ${D}(inbound VLESS no encontrado)${N}"
  fi

  echo ""
  echo -e "  ${W}${BOLD}── USUARIOS VMESS ──${N}"
  sep
  local vmess_idx
  vmess_idx="$(get_inbound_index vmess)"

  if [[ -n "$vmess_idx" ]]; then
    local vmess_count
    vmess_count=$(jq --argjson idx "$vmess_idx" '.inbounds[$idx].settings.clients | length' "$config" 2>/dev/null || echo "0")

    if [[ "$vmess_count" -eq 0 ]]; then
      echo -e "  ${D}(sin usuarios)${N}"
    else
      printf "  ${D}%-4s %-18s %-12s %-6s %-6s${N}\n" "N°" "Usuario" "Expira" "Días" "Estado"
      for (( i = 0; i < vmess_count; i++ )); do
        local user fecha blocked exp status_txt status_color
        user=$(jq -r --argjson idx "$vmess_idx" --argjson a "$i" '.inbounds[$idx].settings.clients[$a].email // "sin-nombre"' "$config")
        fecha=$(jq -r --argjson idx "$vmess_idx" --argjson a "$i" '.inbounds[$idx].settings.clients[$a].date // "∞"' "$config")
        blocked=$(jq -r --argjson idx "$vmess_idx" --argjson a "$i" '.inbounds[$idx].settings.clients[$a].blocked // "false"' "$config")

        if [[ "$blocked" == "true" ]]; then
          status_txt="BLOQ"; status_color="$R"; exp="-"
        elif [[ "$fecha" != "∞" && "$fecha" != "null" && "$fecha" != "N/A" ]]; then
          local seg_exp
          seg_exp=$(date +%s --date="$fecha" 2>/dev/null || echo "0")
          exp="$(( (seg_exp - seg) / 86400 ))"
          (( exp < 0 )) && { status_txt="EXP"; status_color="$R"; exp="0"; } || { status_txt="OK"; status_color="$G"; }
        else
          exp="∞"; status_txt="OK"; status_color="$G"
        fi

        printf "  ${G}%-4s${N} ${C}%-18s${N} ${Y}%-12s${N} ${W}%-6s${N} ${status_color}%-6s${N}\n" \
          "[$i]" "$user" "$fecha" "$exp" "$status_txt"
      done
    fi
  else
    echo -e "  ${D}(inbound VMess no encontrado)${N}"
  fi
}

# =========================================================
#  GENERAR LINK VLESS
# =========================================================

show_vless_link() {
  local idx="$1"
  local inb_idx
  inb_idx="$(get_inbound_index vless)"
  [[ -z "$inb_idx" ]] && { echo -e "  ${R}✗ Inbound VLESS no encontrado${N}"; return; }

  local user id add host net path port tls sni

  user=$(jq -r --argjson ii "$inb_idx" --argjson a "$idx" '.inbounds[$ii].settings.clients[$a].email // "default"' "$config")
  id=$(jq -r --argjson ii "$inb_idx" --argjson a "$idx" '.inbounds[$ii].settings.clients[$a].id' "$config")
  add=$(jq -r '.inbounds[0].domain // empty' "$config")
  [[ -z "$add" || "$add" == "null" ]] && add="$(get_ip)"
  host=$(jq -r --argjson ii "$inb_idx" '.inbounds[$ii].streamSettings.wsSettings.headers.Host // ""' "$config")
  net=$(jq -r --argjson ii "$inb_idx" '.inbounds[$ii].streamSettings.network // "ws"' "$config")
  path=$(jq -r --argjson ii "$inb_idx" '.inbounds[$ii].streamSettings.wsSettings.path // "/vless"' "$config")
  port=$(jq -r '.inbounds[0].port' "$config")
  tls=$(jq -r --argjson ii "$inb_idx" '.inbounds[$ii].streamSettings.security // "none"' "$config")
  sni="$host"
  [[ -z "$sni" || "$sni" == "null" ]] && sni="$add"

  echo ""
  echo -e "  ${W}${BOLD}V2RAY VLESS — ${C}${user}${N}"
  sep
  echo -e "    ${W}Address:${N}      ${Y}${add}${N}"
  echo -e "    ${W}Port:${N}         ${Y}${port}${N}"
  echo -e "    ${W}UUID:${N}         ${C}${id}${N}"
  echo -e "    ${W}Encryption:${N}   ${C}none${N}"
  echo -e "    ${W}Network:${N}      ${C}${net}${N}"
  [[ -n "$host" && "$host" != "null" && -n "$host" ]] && echo -e "    ${W}Host:${N}         ${C}${host}${N}"
  echo -e "    ${W}Path:${N}         ${C}${path}${N}"
  echo -e "    ${W}TLS:${N}          ${Y}${tls}${N}"
  sep

  local params="encryption=none&type=${net}"
  [[ -n "$host" && "$host" != "null" && -n "$host" ]] && params="${params}&host=${host}"
  params="${params}&path=$(echo "$path" | sed 's|/|%2F|g')"
  [[ "$tls" != "none" ]] && params="${params}&security=${tls}&sni=${sni}" || params="${params}&security=none"

  local link="vless://${id}@${add}:${port}?${params}#${user}"

  echo ""
  echo -e "  ${W}${BOLD}LINK:${N}"
  echo -e "  ${Y}${link}${N}"
  sep
}

# =========================================================
#  GENERAR LINK VMESS
# =========================================================

show_vmess_link() {
  local idx="$1"
  local inb_idx
  inb_idx="$(get_inbound_index vmess)"
  [[ -z "$inb_idx" ]] && { echo -e "  ${R}✗ Inbound VMess no encontrado${N}"; return; }

  local user id aid add host net path port tls

  user=$(jq -r --argjson ii "$inb_idx" --argjson a "$idx" '.inbounds[$ii].settings.clients[$a].email // "default"' "$config")
  id=$(jq -r --argjson ii "$inb_idx" --argjson a "$idx" '.inbounds[$ii].settings.clients[$a].id' "$config")
  aid=$(jq -r --argjson ii "$inb_idx" --argjson a "$idx" '.inbounds[$ii].settings.clients[$a].alterId // 0' "$config")
  add=$(jq -r '.inbounds[0].domain // empty' "$config")
  [[ -z "$add" || "$add" == "null" ]] && add="$(get_ip)"
  host=$(jq -r --argjson ii "$inb_idx" '.inbounds[$ii].streamSettings.wsSettings.headers.Host // ""' "$config")
  net=$(jq -r --argjson ii "$inb_idx" '.inbounds[$ii].streamSettings.network // "ws"' "$config")
  path=$(jq -r --argjson ii "$inb_idx" '.inbounds[$ii].streamSettings.wsSettings.path // "/vmess"' "$config")
  port=$(jq -r '.inbounds[0].port' "$config")
  tls=$(jq -r --argjson ii "$inb_idx" '.inbounds[$ii].streamSettings.security // "none"' "$config")

  echo ""
  echo -e "  ${W}${BOLD}V2RAY VMESS — ${C}${user}${N}"
  sep
  echo -e "    ${W}Address:${N}      ${Y}${add}${N}"
  echo -e "    ${W}Port:${N}         ${Y}${port}${N}"
  echo -e "    ${W}UUID:${N}         ${C}${id}${N}"
  echo -e "    ${W}AlterId:${N}      ${C}${aid}${N}"
  echo -e "    ${W}Network:${N}      ${C}${net}${N}"
  [[ -n "$host" && "$host" != "null" && -n "$host" ]] && echo -e "    ${W}Host:${N}         ${C}${host}${N}"
  echo -e "    ${W}Path:${N}         ${C}${path}${N}"
  echo -e "    ${W}TLS:${N}          ${Y}${tls}${N}"
  sep

  local json_vmess="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${add}\",\"port\":${port},\"aid\":${aid},\"type\":\"none\",\"net\":\"${net}\",\"path\":\"${path}\",\"host\":\"${host}\",\"id\":\"${id}\",\"tls\":\"${tls}\"}"
  local link="vmess://$(echo "$json_vmess" | base64 -w 0 2>/dev/null || echo "$json_vmess" | base64 2>/dev/null)"

  echo ""
  echo -e "  ${W}${BOLD}LINK:${N}"
  echo -e "  ${Y}${link}${N}"
  sep
}

# =========================================================
#  CREAR USUARIO
# =========================================================

new_user() {
  clear
  hr
  echo -e "${W}${BOLD}          CREAR NUEVO USUARIO${N}"
  hr

  # Elegir protocolo primero
  echo ""
  echo -e "  ${W}${BOLD}Seleccionar protocolo:${N}"
  echo -e "  ${G}[${W}1${G}]${N}  ${C}V2Ray VLESS${N} ${D}(ligero, sin cifrado extra)${N}"
  echo -e "  ${G}[${W}2${G}]${N}  ${C}V2Ray VMess${N} ${D}(compatible con más clientes)${N}"
  sep

  local proto_choice=""
  while true; do
    echo -ne "  ${W}Protocolo [${D}1${W}]: ${G}"
    read -r proto_choice
    echo -ne "${N}"
    proto_choice="${proto_choice:-1}"
    [[ "$proto_choice" == "1" || "$proto_choice" == "2" ]] && break
    echo -e "  ${R}✗${N} ${W}Elige 1 o 2${N}"
  done

  local selected_proto="vless"
  local inb_tag="vless-in"
  [[ "$proto_choice" == "2" ]] && { selected_proto="vmess"; inb_tag="vmess-in"; }

  local inb_idx
  inb_idx="$(get_inbound_index "$selected_proto")"
  if [[ -z "$inb_idx" ]]; then
    echo -e "  ${R}✗${N} ${W}Inbound ${selected_proto} no encontrado en config${N}"
    pause
    return
  fi

  # Nombre
  echo ""
  list_all_users
  sep

  local email=""
  while true; do
    echo -ne "  ${W}Nombre de usuario: ${G}"
    read -r email
    echo -ne "${N}"
    [[ "$email" == "0" ]] && return

    if [[ -z "$email" ]]; then
      echo -e "  ${R}✗${N} ${W}No vacío${N}"
    elif [[ ! "$email" =~ $tx_num ]]; then
      echo -e "  ${R}✗${N} ${W}Solo letras, números y _${N}"
    elif [[ "${#email}" -lt 4 ]]; then
      echo -e "  ${R}✗${N} ${W}Mínimo 4 caracteres${N}"
    elif jq -r '.inbounds[].settings.clients[].email // empty' "$config" 2>/dev/null | grep -qx "$email"; then
      echo -e "  ${R}✗${N} ${W}Ya existe${N}"
    else
      break
    fi
  done

  # Días
  local dias=""
  while true; do
    echo -ne "  ${W}Días de duración: ${G}"
    read -r dias
    echo -ne "${N}"
    [[ "$dias" == "0" ]] && return
    [[ "$dias" =~ $numero ]] && (( dias >= 1 )) && break
    echo -e "  ${R}✗${N} ${W}Número válido${N}"
  done

  local fecha_exp
  fecha_exp=$(date '+%y-%m-%d' -d "+${dias} days")

  # UUID
  echo ""
  sep
  echo -e "  ${D}Enter = UUID automático | O pega uno personalizado${N}"
  sep
  echo -ne "  ${W}UUID: ${G}"
  read -r custom_uuid
  echo -ne "${N}"

  local uuid=""
  if [[ -z "$custom_uuid" ]]; then
    uuid="$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen)"
    echo -e "  ${G}✓${N} ${W}UUID: ${C}${uuid}${N}"
  else
    uuid="$custom_uuid"
    echo -e "  ${G}✓${N} ${W}UUID personalizado aceptado${N}"
  fi

  # Resumen
  echo ""
  hr
  echo -e "  ${W}${BOLD}RESUMEN:${N}"
  sep
  echo -e "    ${W}Protocolo:${N}  ${C}${selected_proto^^}${N}"
  echo -e "    ${W}Nombre:${N}     ${Y}${email}${N}"
  echo -e "    ${W}UUID:${N}       ${C}${uuid}${N}"
  echo -e "    ${W}Expira:${N}     ${Y}${fecha_exp}${N} ${D}(${dias} días)${N}"
  sep
  echo -ne "  ${W}¿Crear? (s/n): ${G}"
  read -r confirm
  echo -ne "${N}"
  [[ "${confirm,,}" == "s" ]] || { echo -e "  ${Y}Cancelado${N}"; pause; return; }

  echo ""

  # Construir objeto cliente
  local new_client
  if [[ "$selected_proto" == "vless" ]]; then
    new_client=$(jq -n --arg id "$uuid" --arg email "$email" --arg date "$fecha_exp" \
      '{"id":$id,"email":$email,"date":$date,"encryption":"none","flow":""}')
  else
    new_client=$(jq -n --arg id "$uuid" --arg email "$email" --arg date "$fecha_exp" \
      '{"id":$id,"email":$email,"date":$date,"alterId":0}')
  fi

  # Agregar al inbound correcto
  local temp
  temp=$(mktemp)
  jq --argjson idx "$inb_idx" --argjson client "$new_client" \
    '.inbounds[$idx].settings.clients += [$client]' "$config" > "$temp" && mv "$temp" "$config"
  chmod 644 "$config"

  service_restart
  log_msg "Usuario creado: $email ($selected_proto)"

  # Mostrar link
  local user_idx
  user_idx=$(jq --argjson idx "$inb_idx" '.inbounds[$idx].settings.clients | length - 1' "$config" 2>/dev/null)

  clear
  hr
  if [[ "$selected_proto" == "vless" ]]; then
    show_vless_link "$user_idx"
  else
    show_vmess_link "$user_idx"
  fi
  hr
  pause
}

# =========================================================
#  ELIMINAR USUARIO
# =========================================================

del_user() {
  clear
  hr
  echo -e "${W}${BOLD}          ELIMINAR USUARIO${N}"
  hr
  echo ""

  echo -e "  ${G}[${W}1${G}]${N}  ${C}Eliminar usuario VLESS${N}"
  echo -e "  ${G}[${W}2${G}]${N}  ${C}Eliminar usuario VMess${N}"
  sep
  echo -ne "  ${W}Protocolo: ${G}"
  read -r pc
  echo -ne "${N}"
  [[ "$pc" == "0" ]] && return

  local proto="vless"
  [[ "$pc" == "2" ]] && proto="vmess"

  local inb_idx
  inb_idx="$(get_inbound_index "$proto")"
  [[ -z "$inb_idx" ]] && { echo -e "  ${R}✗ Inbound no encontrado${N}"; pause; return; }

  local count
  count=$(jq --argjson idx "$inb_idx" '.inbounds[$idx].settings.clients | length' "$config" 2>/dev/null || echo "0")
  [[ "$count" -eq 0 ]] && { echo -e "  ${Y}⚠ Sin usuarios${N}"; pause; return; }

  echo ""
  echo -e "  ${W}${BOLD}Usuarios ${proto^^}:${N}"
  sep
  for (( i = 0; i < count; i++ )); do
    local u
    u=$(jq -r --argjson idx "$inb_idx" --argjson a "$i" '.inbounds[$idx].settings.clients[$a].email // "N/A"' "$config")
    echo -e "  ${G}[${W}$i${G}]${N}  ${C}${u}${N}"
  done
  sep

  local opc=""
  while true; do
    echo -ne "  ${W}N° a eliminar: ${G}"
    read -r opc
    echo -ne "${N}"
    [[ "$opc" == "0" && "$count" -gt 0 ]] && { # 0 puede ser usuario válido
      break
    }
    [[ "$opc" =~ $numero ]] && (( opc < count )) && break
    echo -e "  ${R}✗ Inválido${N}"
  done

  local user_name
  user_name=$(jq -r --argjson idx "$inb_idx" --argjson a "$opc" '.inbounds[$idx].settings.clients[$a].email // "N/A"' "$config")

  echo -ne "  ${W}¿Eliminar ${R}${user_name}${W}? (s/n): ${G}"
  read -r confirm
  echo -ne "${N}"
  [[ "${confirm,,}" == "s" ]] || return

  local temp
  temp=$(mktemp)
  jq --argjson idx "$inb_idx" --argjson a "$opc" 'del(.inbounds[$idx].settings.clients[$a])' "$config" > "$temp" && mv "$temp" "$config"
  chmod 644 "$config"

  echo ""
  service_restart
  echo ""
  echo -e "  ${G}✓${N} ${W}Usuario ${R}${user_name}${W} eliminado${N}"
  log_msg "Eliminado: $user_name ($proto)"
  pause
}

# =========================================================
#  VER DATOS / LINK
# =========================================================

view_user() {
  clear
  hr
  echo -e "${W}${BOLD}          VER DATOS / LINK${N}"
  hr
  echo ""

  echo -e "  ${G}[${W}1${G}]${N}  ${C}Ver usuario VLESS${N}"
  echo -e "  ${G}[${W}2${G}]${N}  ${C}Ver usuario VMess${N}"
  sep
  echo -ne "  ${W}Protocolo: ${G}"
  read -r pc
  echo -ne "${N}"
  [[ "$pc" == "0" ]] && return

  local proto="vless"
  [[ "$pc" == "2" ]] && proto="vmess"

  local inb_idx
  inb_idx="$(get_inbound_index "$proto")"
  [[ -z "$inb_idx" ]] && { echo -e "  ${R}✗ Inbound no encontrado${N}"; pause; return; }

  local count
  count=$(jq --argjson idx "$inb_idx" '.inbounds[$idx].settings.clients | length' "$config" 2>/dev/null || echo "0")
  [[ "$count" -eq 0 ]] && { echo -e "  ${Y}⚠ Sin usuarios${N}"; pause; return; }

  echo ""
  for (( i = 0; i < count; i++ )); do
    local u
    u=$(jq -r --argjson idx "$inb_idx" --argjson a "$i" '.inbounds[$idx].settings.clients[$a].email // "N/A"' "$config")
    echo -e "  ${G}[${W}$i${G}]${N}  ${C}${u}${N}"
  done
  sep

  local opc=""
  while true; do
    echo -ne "  ${W}N° del usuario: ${G}"
    read -r opc
    echo -ne "${N}"
    [[ "$opc" =~ $numero ]] && (( opc < count )) && break
    echo -e "  ${R}✗ Inválido${N}"
  done

  clear
  hr
  if [[ "$proto" == "vless" ]]; then
    show_vless_link "$opc"
  else
    show_vmess_link "$opc"
  fi
  hr
  pause
}

# =========================================================
#  RENOVAR USUARIO
# =========================================================

renew_user() {
  clear
  hr
  echo -e "${W}${BOLD}          RENOVAR USUARIO${N}"
  hr
  echo ""

  echo -e "  ${G}[${W}1${G}]${N}  ${C}Renovar VLESS${N}"
  echo -e "  ${G}[${W}2${G}]${N}  ${C}Renovar VMess${N}"
  sep
  echo -ne "  ${W}Protocolo: ${G}"
  read -r pc
  echo -ne "${N}"
  [[ "$pc" == "0" ]] && return

  local proto="vless"
  [[ "$pc" == "2" ]] && proto="vmess"

  local inb_idx
  inb_idx="$(get_inbound_index "$proto")"
  [[ -z "$inb_idx" ]] && { echo -e "  ${R}✗ Inbound no encontrado${N}"; pause; return; }

  local count
  count=$(jq --argjson idx "$inb_idx" '.inbounds[$idx].settings.clients | length' "$config" 2>/dev/null || echo "0")
  [[ "$count" -eq 0 ]] && { echo -e "  ${Y}⚠ Sin usuarios${N}"; pause; return; }

  echo ""
  for (( i = 0; i < count; i++ )); do
    local u d
    u=$(jq -r --argjson idx "$inb_idx" --argjson a "$i" '.inbounds[$idx].settings.clients[$a].email // "N/A"' "$config")
    d=$(jq -r --argjson idx "$inb_idx" --argjson a "$i" '.inbounds[$idx].settings.clients[$a].date // "∞"' "$config")
    echo -e "  ${G}[${W}$i${G}]${N}  ${C}${u}${N} ${D}(exp: ${d})${N}"
  done
  sep

  local opc=""
  while true; do
    echo -ne "  ${W}N° a renovar: ${G}"
    read -r opc
    echo -ne "${N}"
    [[ "$opc" =~ $numero ]] && (( opc < count )) && break
    echo -e "  ${R}✗ Inválido${N}"
  done

  local dias=""
  while true; do
    echo -ne "  ${W}Días adicionales: ${G}"
    read -r dias
    echo -ne "${N}"
    [[ "$dias" =~ $numero ]] && (( dias >= 1 )) && break
    echo -e "  ${R}✗ Número válido${N}"
  done

  local current_date new_date
  current_date=$(jq -r --argjson idx "$inb_idx" --argjson a "$opc" '.inbounds[$idx].settings.clients[$a].date // ""' "$config")
  if [[ -n "$current_date" && "$current_date" != "null" && "$current_date" != "∞" ]]; then
    new_date=$(date '+%y-%m-%d' -d "$current_date +$dias days" 2>/dev/null || date '+%y-%m-%d' -d "+$dias days")
  else
    new_date=$(date '+%y-%m-%d' -d "+$dias days")
  fi

  local temp
  temp=$(mktemp)
  jq --argjson idx "$inb_idx" --argjson a "$opc" --arg d "$new_date" \
    '.inbounds[$idx].settings.clients[$a].date = $d | .inbounds[$idx].settings.clients[$a].blocked = false' \
    "$config" > "$temp" && mv "$temp" "$config"
  chmod 644 "$config"

  service_restart
  local user_name
  user_name=$(jq -r --argjson idx "$inb_idx" --argjson a "$opc" '.inbounds[$idx].settings.clients[$a].email' "$config")
  echo ""
  echo -e "  ${G}✓${N} ${W}${user_name} renovado hasta ${Y}${new_date}${N}"
  log_msg "Renovado: $user_name ($proto) +$dias"
  pause
}

# =========================================================
#  BLOQUEAR USUARIO
# =========================================================

block_user() {
  clear
  hr
  echo -e "${W}${BOLD}          BLOQUEAR USUARIO${N}"
  hr
  echo ""

  echo -e "  ${G}[${W}1${G}]${N}  ${C}Bloquear VLESS${N}"
  echo -e "  ${G}[${W}2${G}]${N}  ${C}Bloquear VMess${N}"
  sep
  echo -ne "  ${W}Protocolo: ${G}"
  read -r pc
  echo -ne "${N}"
  [[ "$pc" == "0" ]] && return

  local proto="vless"
  [[ "$pc" == "2" ]] && proto="vmess"

  local inb_idx
  inb_idx="$(get_inbound_index "$proto")"
  [[ -z "$inb_idx" ]] && { echo -e "  ${R}✗ Inbound no encontrado${N}"; pause; return; }

  local count
  count=$(jq --argjson idx "$inb_idx" '.inbounds[$idx].settings.clients | length' "$config" 2>/dev/null || echo "0")
  [[ "$count" -eq 0 ]] && { echo -e "  ${Y}⚠ Sin usuarios${N}"; pause; return; }

  echo ""
  for (( i = 0; i < count; i++ )); do
    local u
    u=$(jq -r --argjson idx "$inb_idx" --argjson a "$i" '.inbounds[$idx].settings.clients[$a].email // "N/A"' "$config")
    echo -e "  ${G}[${W}$i${G}]${N}  ${C}${u}${N}"
  done
  sep

  local opc=""
  while true; do
    echo -ne "  ${W}N° a bloquear: ${G}"
    read -r opc
    echo -ne "${N}"
    [[ "$opc" =~ $numero ]] && (( opc < count )) && break
    echo -e "  ${R}✗ Inválido${N}"
  done

  local temp
  temp=$(mktemp)
  jq --argjson idx "$inb_idx" --argjson a "$opc" \
    '.inbounds[$idx].settings.clients[$a].blocked = true' \
    "$config" > "$temp" && mv "$temp" "$config"
  chmod 644 "$config"

  service_restart
  local user_name
  user_name=$(jq -r --argjson idx "$inb_idx" --argjson a "$opc" '.inbounds[$idx].settings.clients[$a].email' "$config")
  echo ""
  echo -e "  ${G}✓${N} ${W}${user_name} bloqueado${N}"
  log_msg "Bloqueado: $user_name ($proto)"
  pause
}

# =========================================================
#  RESPALDO
# =========================================================

backup_users() {
  clear
  hr
  echo -e "${W}${BOLD}          COPIAS DE SEGURIDAD${N}"
  hr
  echo ""
  echo -e "  ${G}[${W}1${G}]${N}  ${C}Crear copia${N}"
  echo -e "  ${G}[${W}2${G}]${N}  ${C}Restaurar copia${N}"
  sep
  echo -e "  ${G}[${W}0${G}]${N}  ${W}Volver${N}"
  sep
  echo -ne "  ${W}Opción: ${G}"
  read -r op
  echo -ne "${N}"

  case "${op:-}" in
    1)
      local backup="/root/V2ray-Backup.json"
      jq '.inbounds' "$config" > "$backup" 2>/dev/null
      echo -e "  ${G}✓${N} ${W}Copia creada: ${C}${backup}${N}"
      echo -e "  ${D}Incluye usuarios de VLESS y VMess${N}"
      log_msg "Backup creado"
      ;;
    2)
      local backup="/root/V2ray-Backup.json"
      [[ ! -f "$backup" ]] && { echo -e "  ${R}✗ No hay copia${N}"; pause; return; }
      echo -ne "  ${W}¿Restaurar? (s/n): ${G}"
      read -r c
      echo -ne "${N}"
      [[ "${c,,}" == "s" ]] || return

      local backup_data
      backup_data="$(cat "$backup")"
      local temp
      temp=$(mktemp)
      jq --argjson inb "$backup_data" '.inbounds = $inb' "$config" > "$temp" && mv "$temp" "$config"
      chmod 644 "$config"
      service_restart
      echo -e "  ${G}✓${N} ${W}Restaurado${N}"
      log_msg "Backup restaurado"
      ;;
    0) return ;;
  esac
  pause
}

# =========================================================
#  MENÚ PRINCIPAL
# =========================================================

main_menu() {
  check_deps

  while true; do
    detect_config
    clear

    local port_v2 vless_c vmess_c
    port_v2="$(get_port)"
    vless_c="$(get_vless_count)"
    vmess_c="$(get_vmess_count)"

    hr
    echo -e "${W}${BOLD}        GESTIÓN DE USUARIOS (VMess + VLESS)${N}"
    hr
    echo -e "  ${W}PUERTO:${N}  ${Y}${port_v2}${N}"
    echo -e "  ${W}VLESS:${N}   ${C}${vless_c} usuarios${N}   ${W}VMESS:${N}  ${C}${vmess_c} usuarios${N}"
    hr
    echo ""
    echo -e "  ${G}[${W}1${G}]${N}  ${C}Crear usuario${N}"
    echo -e "  ${G}[${W}2${G}]${N}  ${C}Eliminar usuario${N}"
    echo -e "  ${G}[${W}3${G}]${N}  ${C}Ver datos / Link${N}"
    sep
    echo -e "  ${G}[${W}4${G}]${N}  ${C}Renovar usuario${N}"
    echo -e "  ${G}[${W}5${G}]${N}  ${C}Bloquear usuario${N}"
    echo -e "  ${G}[${W}6${G}]${N}  ${C}Respaldo de seguridad${N}"
    sep
    echo -e "  ${G}[${W}7${G}]${N}  ${C}Ver todos los usuarios${N}"
    hr
    echo -e "  ${G}[${W}0${G}]${N}  ${W}Volver${N}"
    hr
    echo ""
    echo -ne "  ${W}Opción: ${G}"
    read -r opcion
    echo -ne "${N}"

    case "${opcion:-}" in
      1) new_user ;;
      2) del_user ;;
      3) view_user ;;
      4) renew_user ;;
      5) block_user ;;
      6) backup_users ;;
      7) clear; hr; echo -e "${W}${BOLD}          TODOS LOS USUARIOS${N}"; hr; echo ""; list_all_users; echo ""; hr; pause ;;
      0) break ;;
      *) echo -e "  ${R}Opción inválida${N}"; sleep 1 ;;
    esac
  done

  exit 0
}

trap 'echo -ne "${N}"; tput cnorm 2>/dev/null; exit 0' SIGINT SIGTERM

main_menu
