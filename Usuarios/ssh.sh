#!/bin/bash
# =========================================================
# SinNombre v2.0 - Gestión de Usuarios SSH
# Archivo: Usuarios/ssh.sh
# =========================================================

# ── Cargar colores y funciones desde lib ────────────────
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/colores.sh" 2>/dev/null \
  || source "/etc/SN/lib/colores.sh" 2>/dev/null || {
  echo "ERROR: No se pudo cargar lib/colores.sh"
  exit 1
}

# ── Rutas SN ────────────────────────────────────────────
VPS_user="/etc/SN"
VPS_inst="/etc/SN/install"
USRdatabase="/etc/SN/usuarios"
mkdir -p "$VPS_user" "$VPS_inst" "$USRdatabase"
USRdatabase="${VPS_user}/VPSuser"
[[ ! -d "${VPS_user}/B-VPSuser" ]] && mkdir -p "${VPS_user}/B-VPSuser"

# ── Funciones auxiliares del menú SSH ───────────────────
back() {
  msg -bar3
  echo -e "${R}[${Y}0${R}]${N}  ${C}Volver${N}"
  msg -bar3
}

menu_func() {
  local i=1
  for opt in "$@"; do
    echo -e "${R}[${Y}$i${R}]${N}  ${C}$opt${N}"
    ((i++))
  done
}

selection_fun() {
  local max="$1"
  local opt
  while true; do
    read -p " Opción: " opt
    [[ "$opt" =~ ^[0-9]+$ ]] && [[ "$opt" -ge 0 && "$opt" -le "$max" ]] && {
      echo "$opt"
      return
    }
  done
}

print_center_bar() {
  local text="$1"
  local bar_len=50
  local len=${#text}
  local padding=$(( (bar_len - len) / 2 ))
  [[ $padding -gt 0 ]] && printf '%*s' "$padding" ''
  echo -e "$text"
}

fun_ip() {
  curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}'
}

fun_trans() {
  echo "$*"
}

droppids() {
  ps aux | grep dropbear | grep -v grep | awk '{print $2, $1}'
}

# =========================================================
# OBTENER INFORMACIÓN COMPLETA DEL VPS (puertos, sistema...)
# =========================================================
get_vps_system_info() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    VPS_DISTRO="${PRETTY_NAME:-$(uname -rs)}"
  else
    VPS_DISTRO="$(uname -rs)"
  fi
  VPS_IP="$(fun_ip)"
  VPS_DOMINIO=""
  [[ -f "/etc/SN/dominio.txt" ]] && VPS_DOMINIO="$(cat /etc/SN/dominio.txt)"
  VPS_ZONA="$(timedatectl 2>/dev/null | awk -F': ' '/Time zone/ {print $2}' | awk '{print $1}' || date +%Z)"
  read -r VPS_MEM_TOTAL VPS_MEM_USADA VPS_MEM_LIBRE <<< "$(free -m | awk '/^Mem:/ {print $2, $3, $7}')"
}

get_active_ports() {
  local ss_output
  ss_output="$(ss -Hlntup 2>/dev/null)" || ss_output=""

  # Arrays para clasificar puertos
  PORTS_MAIN=""
  PORTS_EXTRA=""
  PORTS_SLOWDNS=""
  SLOWDNS_NS=""
  SLOWDNS_KEY=""

  declare -A svc_ports=()

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local proto port proc
    if echo "$line" | grep -qE '^udp|UNCONN'; then
      proto="UDP"
    else
      proto="TCP"
    fi
    port="$(echo "$line" | awk '{print $5}' | awk -F: '{print $NF}')"
    [[ -z "$port" || ! "$port" =~ ^[0-9]+$ ]] && continue
    proc="$(echo "$line" | sed -n 's/.*users:(("\([^"]*\)".*/\1/p')"
    [[ -z "$proc" ]] && continue

    local svc_name=""
    case "$proc" in
      sshd)              svc_name="SSH" ;;
      dropbear)          svc_name="DROPBEAR" ;;
      v2ray)             svc_name="V2RAY" ;;
      xray)              svc_name="XRAY" ;;
      squid|squid3)      svc_name="SQUID" ;;
      stunnel|stunnel4)  svc_name="SSL WS" ;;
      openvpn)           svc_name="OPENVPN" ;;
      badvpn-udpgw)      svc_name="BADVPN" ;;
      python3|python)    svc_name="PYTHON" ;;
      nginx)             svc_name="NGINX" ;;
      node)              svc_name="NODE" ;;
      udp-custom|udpgw)  svc_name="UDPCUSTOM" ;;
      wireguard-go|wg)   svc_name="WIREGUARD" ;;
      dns2socks|dnstt-server|slowdns) svc_name="SLOWDNS" ;;
      *)                 svc_name="$proc" ;;
    esac

    # Omitir puertos UDP internos de v2ray/xray
    if [[ "$proto" == "UDP" && ("$svc_name" == "V2RAY" || "$svc_name" == "XRAY") ]]; then
      continue
    fi

    local port_label="$port"
    [[ "$proto" == "UDP" ]] && port_label="${port}"

    if [[ -z "${svc_ports[$svc_name]:-}" ]]; then
      svc_ports[$svc_name]="$port_label"
    elif [[ "${svc_ports[$svc_name]}" != *"$port_label"* ]]; then
      svc_ports[$svc_name]="${svc_ports[$svc_name]}, $port_label"
    fi
  done <<< "$ss_output"

  # Clasificar en principales vs extras
  for svc in "${!svc_ports[@]}"; do
    local p="${svc_ports[$svc]}"
    case "$svc" in
      SSH|DROPBEAR|PYTHON|SQUID|NGINX|SSL\ WS|OPENVPN|V2RAY|XRAY)
        PORTS_MAIN+="⇥ ${svc}: ${p}\n"
        ;;
      SLOWDNS)
        PORTS_SLOWDNS+="⇥ 🐌 SLOWDNS: ${p}\n"
        ;;
      *)
        PORTS_EXTRA+="⇥ ${svc}: ${p}\n"
        ;;
    esac
  done

  # SlowDNS: intentar obtener nameserver y key
  if [[ -f /etc/SN/slowdns/ns.txt ]]; then
    SLOWDNS_NS="$(cat /etc/SN/slowdns/ns.txt 2>/dev/null)"
  fi
  if [[ -f /etc/SN/slowdns/public.key ]]; then
    SLOWDNS_KEY="$(cat /etc/SN/slowdns/public.key 2>/dev/null)"
  elif [[ -f /root/udp/public.key ]]; then
    SLOWDNS_KEY="$(cat /root/udp/public.key 2>/dev/null)"
  fi
}

# =========================================================
# MOSTRAR INFO COMPLETA DEL USUARIO CREADO (estilo HTTP Custom)
# =========================================================
show_user_info() {
  local usuario="$1"
  local contrasena="$2"
  local dias="$3"
  local limite="$4"
  local zip_file="${5:-}"

  get_vps_system_info
  get_active_ports

  local fecha_exp
  fecha_exp="$(date "+%Y-%m-%d" -d " + ${dias} days")"

  echo ""
  msg -bar
  echo -e "${Y}        【 ☬ USUARIO CREADO EXITOSAMENTE ☬ 】${N}"
  msg -bar
  echo -e "${W}❍ ✅ Usuario creado con éxito${N}"
  echo -e "${W}❍ 👤 Usuario:${N}     ${G}${usuario}${N}"
  echo -e "${W}❍ 🔐 Contraseña:${N}  ${G}${contrasena}${N}"
  echo -e "${W}❍ 🔗 Limite:${N}      ${G}${limite}${N}"
  echo -e "${W}❒ 🕑 Duración:${N}    ${Y}${dias} días${N}"
  echo -e "${W}❒ 📅 Expira:${N}      ${Y}${fecha_exp}${N}"
  [[ -n "$zip_file" ]] && \
  echo -e "${W}❒ 📂 Archivo:${N}     ${C}${zip_file}${N}"

  echo -e "${R}──────INFORMACION DEL VPS ──────${N}"
  echo -e "${W}› sistema:${N}       ${Y}${VPS_DISTRO}${N}"
  [[ -n "$VPS_DOMINIO" ]] && \
  echo -e "${W}› ◤ᴅᴏᴍɪɴɪᴏ ⏤͟͟͞͞➪:${N} ${Y}${VPS_DOMINIO}${N}"
  echo -e "${W}› ip vps:${N}        ${Y}${VPS_IP}${N}"
  echo -e "${W}› ᴢᴏɴᴀ ʜᴏʀᴀʀɪᴀ:${N}  ${Y}${VPS_ZONA}${N}"
  echo -e "${W}› ᴍᴇᴍᴏʀɪᴀ:${N}      ${Y}${VPS_MEM_TOTAL} MB${N}"
  echo -e "${W}› ᴜsᴏ:${N}           ${Y}${VPS_MEM_USADA} MB${N}"
  echo -e "${W}› ʟɪʙʀᴇ:${N}         ${G}${VPS_MEM_LIBRE} MB${N}"

  if [[ -n "$PORTS_MAIN" ]]; then
    echo -e "${R}──────PUERTOS ACTIVOS ──────${N}"
    echo -ne "${C}${PORTS_MAIN}${N}"
  fi

  if [[ -n "$PORTS_EXTRA" ]]; then
    echo -e "${R}──────SERVICIOS EXTRA ──────${N}"
    echo -ne "${C}${PORTS_EXTRA}${N}"
  fi

  if [[ -n "$PORTS_SLOWDNS" ]]; then
    echo -e "${R}──────SLOWDNS ──────${N}"
    echo -ne "${C}${PORTS_SLOWDNS}${N}"
    [[ -n "$SLOWDNS_NS" ]] && \
    echo -e "${C}⇥ ɴᴀᴍᴇsᴇʀᴠᴇʀ:${N} ${Y}${SLOWDNS_NS}${N}"
    [[ -n "$SLOWDNS_KEY" ]] && \
    echo -e "${C}⇥ 🔑Key:${N} ${Y}${SLOWDNS_KEY}${N}"
  fi

  msg -bar
  echo -e "${Y}            ►► Presione ENTER para continuar ◄◄${N}"
  read
}

# =========================================================
# VALIDACIÓN DE ERRORES
# =========================================================
err_fun() {
  case "$1" in
    1)  tput cuu1; tput dl1; msg -verm "Usuario Nulo"; sleep 2; tput cuu1; tput dl1 ;;
    2)  tput cuu1; tput dl1; msg -verm "Usuario con nombre muy corto (min 4)"; sleep 2; tput cuu1; tput dl1 ;;
    3)  tput cuu1; tput dl1; msg -verm "Usuario con nombre muy grande (max 12)"; sleep 2; tput cuu1; tput dl1 ;;
    4)  tput cuu1; tput dl1; msg -verm "Contraseña Nula"; sleep 2; tput cuu1; tput dl1 ;;
    5)  tput cuu1; tput dl1; msg -verm "Contraseña muy corta (min 4)"; sleep 2; tput cuu1; tput dl1 ;;
    6)  tput cuu1; tput dl1; msg -verm "Contraseña muy grande (max 12)"; sleep 2; tput cuu1; tput dl1 ;;
    7)  tput cuu1; tput dl1; msg -verm "Duración Nula"; sleep 2; tput cuu1; tput dl1 ;;
    8)  tput cuu1; tput dl1; msg -verm "Duración inválida, utilice números"; sleep 2; tput cuu1; tput dl1 ;;
    9)  tput cuu1; tput dl1; msg -verm "Duración máxima de un año (360)"; sleep 2; tput cuu1; tput dl1 ;;
    11) tput cuu1; tput dl1; msg -verm "Límite Nulo"; sleep 2; tput cuu1; tput dl1 ;;
    12) tput cuu1; tput dl1; msg -verm "Límite inválido, utilice números"; sleep 2; tput cuu1; tput dl1 ;;
    13) tput cuu1; tput dl1; msg -verm "Límite máximo de 999"; sleep 2; tput cuu1; tput dl1 ;;
    14) tput cuu1; tput dl1; msg -verm "Usuario Ya Existe"; sleep 2; tput cuu1; tput dl1 ;;
  esac
}

# =========================================================
# GENERAR ARCHIVO OPENVPN
# =========================================================
newclient() {
  local user="$1"
  local pass="$2"
  local newfile=""
  local ovpnauth=""

  while [[ "${newfile:-}" != @(s|S|y|Y|n|N) ]]; do
    msg -bar
    read -p "Crear Archivo OpenVPN? [S/N]: " -e -i S newfile
    tput cuu1 && tput dl1
  done

  if [[ "${newfile}" = @(s|S) ]]; then
    rm -rf "/etc/openvpn/easy-rsa/pki/reqs/${user}.req"
    rm -rf "/etc/openvpn/easy-rsa/pki/issued/${user}.crt"
    rm -rf "/etc/openvpn/easy-rsa/pki/private/${user}.key"
    cd /etc/openvpn/easy-rsa/ || return
    ./easyrsa build-client-full "$user" nopass > /dev/null 2>&1
    cd || return

    cp /etc/openvpn/client-common.txt ~/"${user}.ovpn"
    {
      echo "<ca>"
      cat /etc/openvpn/easy-rsa/pki/ca.crt
      echo "</ca>"
      echo "<cert>"
      cat "/etc/openvpn/easy-rsa/pki/issued/${user}.crt"
      echo "</cert>"
      echo "<key>"
      cat "/etc/openvpn/easy-rsa/pki/private/${user}.key"
      echo "</key>"
      echo "<tls-auth>"
      cat /etc/openvpn/ta.key
      echo "</tls-auth>"
    } >> ~/"${user}.ovpn"

    while [[ "${ovpnauth:-}" != @(s|S|y|Y|n|N) ]]; do
      read -p "Colocar autenticación de usuario en el archivo? [S/N]: " -e -i S ovpnauth
      tput cuu1 && tput dl1
    done
    [[ "${ovpnauth}" = @(s|S) ]] && sed -i "s;auth-user-pass;<auth-user-pass>\n${user}\n${pass}\n</auth-user-pass>;g" ~/"${user}.ovpn"
    cd "$HOME" || return
    zip "./${user}.zip" "./${user}.ovpn" > /dev/null 2>&1
    rm -f "./${user}.ovpn"
    echo -e "${R}Archivo creado: ($HOME/${user}.zip)${N}"
  fi
}

# =========================================================
# MOSTRAR TABLA DE USUARIOS
# =========================================================
data_user() {
  local cat_users
  cat_users=$(grep 'home' /etc/passwd | grep 'false' | grep -v 'syslog')

  if [[ -z "$(echo "${cat_users}" | awk -F ':' '{print $5}' | cut -d ',' -f1 | grep -v 'hwid' | grep -v 'token' | head -1)" ]]; then
    print_center -verm2 "NO HAY USUARIOS SSH REGISTRADOS"
    return
  fi

  local dat_us
  dat_us=$(printf '%-13s%-14s%-10s%-4s%-6s%s' 'Usuario' 'Contraseña' 'Fecha' 'Dia' 'Limit' 'Statu')
  msg -azu "  $dat_us"
  msg -bar

  local i=1
  for u in $(echo "${cat_users}" | awk -F ':' '{print $1}'); do
    local fix_hwid_token
    fix_hwid_token=$(echo "${cat_users}" | grep -w "$u" | awk -F ':' '{print $5}' | cut -d ',' -f1)
    [[ "${fix_hwid_token}" = @(hwid|token) ]] && continue

    local fecha mes_dia ano us pass stat Limit
    fecha=$(chage -l "$u" | sed -n '4p' | awk -F ': ' '{print $2}')
    mes_dia=$(echo "$fecha" | awk -F ',' '{print $1}' | sed 's/ //g')
    ano=$(echo "$fecha" | awk -F ', ' '{printf $2}' | cut -c 3-)
    us=$(printf '%-12s' "$u")

    pass=$(grep -w "$u" /etc/passwd | awk -F ':' '{print $5}' | cut -d ',' -f2)
    [[ "${#pass}" -gt '12' ]] && pass="Desconocida"
    pass="$(printf '%-12s' "$pass")"

    if [[ $(passwd --status "$u" | cut -d ' ' -f2) = "P" ]]; then
      stat="$(msg -verd "ULK")"
    else
      stat="$(msg -verm2 "LOK")"
    fi

    Limit=$(grep -w "$u" /etc/passwd | awk -F ':' '{print $5}' | cut -d ',' -f1)
    [[ "${#Limit}" = "1" ]] && Limit=$(printf '%2s%-4s' "$Limit") || Limit=$(printf '%-6s' "$Limit")

    echo -ne "$(msg -verd "$i")$(msg -verm2 "-")$(msg -azu "${us}") $(msg -azu "${pass}")"

    if [[ $(echo "$fecha" | awk '{print $2}') = "" ]]; then
      local exp
      exp="$(printf '%8s%-2s' '[X]')"
      exp+="$(printf '%-6s' '[X]')"
      echo " $(msg -verm2 "$fecha")$(msg -verd "$exp")$(echo -e "$stat")"
    else
      if [[ $(date +%s) -gt $(date '+%s' -d "${fecha}") ]]; then
        local exp
        exp="$(printf '%-5s' "Exp")"
        echo " $(msg -verm2 "$mes_dia/$ano")  $(msg -verm2 "$exp")$(msg -ama "$Limit")$(echo -e "$stat")"
      else
        local EXPTIME exp
        EXPTIME="$(( ($(date '+%s' -d "${fecha}") - $(date +%s)) / 86400 ))"
        [[ "${#EXPTIME}" = "1" ]] && exp="$(printf '%2s%-3s' "$EXPTIME")" || exp="$(printf '%-5s' "$EXPTIME")"
        echo " $(msg -verm2 "$mes_dia/$ano")  $(msg -verd "$exp")$(msg -ama "$Limit")$(echo -e "$stat")"
      fi
    fi
    ((i++))
  done
}

# =========================================================
# LISTAR USUARIOS SSH
# =========================================================
mostrar_usuarios() {
  grep 'home' /etc/passwd | grep 'false' | grep -v 'syslog' | grep -v 'hwid' | grep -v 'token' | awk -F ':' '{print $1}'
}

# =========================================================
# CREAR NUEVO USUARIO SSH
# =========================================================
add_user() {
  local user="$1" pass_raw="$2" dias="$3" limite="$4" newfile="$5" ovpnauth="$6"
  local valid zip_ovpn=""

  if grep -w "${user}:" /etc/passwd | grep -vi "[a-z]${user}" | grep -v "[0-9]${user}" > /dev/null 2>&1; then
    return 1
  fi

  valid=$(date '+%C%y-%m-%d' -d " +${dias} days")
  clear
  msg -bar

  local system distro vercion pass_enc
  system=$(head -1 /etc/issue | sed 's/^ *//')
  distro=$(echo "$system" | awk '{print $1}')
  vercion=$(echo "$system" | awk '{print $2}' | cut -d '.' -f1)

  if [[ "${distro}" = @(Ubuntu|Debian) && "${vercion}" = "16" ]]; then
    pass_enc=$(openssl passwd -1 "$pass_raw")
  else
    pass_enc=$(openssl passwd -6 "$pass_raw")
  fi

  if useradd -M -s /bin/false -e "${valid}" -K PASS_MAX_DAYS="${dias}" -p "${pass_enc}" -c "${limite},${pass_raw}" "$user"; then

    if [[ "${newfile}" = @(s|S) ]]; then
      rm -rf "/etc/openvpn/easy-rsa/pki/reqs/${user}.req"
      rm -rf "/etc/openvpn/easy-rsa/pki/issued/${user}.crt"
      rm -rf "/etc/openvpn/easy-rsa/pki/private/${user}.key"
      cd /etc/openvpn/easy-rsa/ || return
      ./easyrsa build-client-full "$user" nopass > /dev/null 2>&1
      cd || return

      cp /etc/openvpn/client-common.txt ~/"${user}.ovpn"
      {
        echo "<ca>"
        cat /etc/openvpn/easy-rsa/pki/ca.crt
        echo "</ca>"
        echo "<cert>"
        cat "/etc/openvpn/easy-rsa/pki/issued/${user}.crt"
        echo "</cert>"
        echo "<key>"
        cat "/etc/openvpn/easy-rsa/pki/private/${user}.key"
        echo "</key>"
        echo "<tls-auth>"
        cat /etc/openvpn/ta.key
        echo "</tls-auth>"
      } >> ~/"${user}.ovpn"

      [[ "${ovpnauth}" = @(s|S) ]] && sed -i "s;auth-user-pass;<auth-user-pass>\n${user}\n${pass_raw}\n</auth-user-pass>;g" ~/"${user}.ovpn"
      cd "$HOME" || return
      zip "./${user}.zip" "./${user}.ovpn" > /dev/null 2>&1
      rm -f "./${user}.ovpn"
      zip_ovpn="$HOME/${user}.zip"
    fi

    # Mostrar info completa estilo HTTP Custom
    show_user_info "$user" "$pass_raw" "$dias" "$limite" "$zip_ovpn"
    return 0
  else
    print_center -verm2 "Error, Usuario no creado"
    msg -bar
    sleep 3
    return 1
  fi
}

new_user() {
  clear
  local usuarios_ativos
  usuarios_ativos=('' $(mostrar_usuarios))

  title "CREAR NUEVO USUARIO SSH ✏️"
  data_user
  back

  local nomeuser=""
  while true; do
    msg -ne "Nombre Del Nuevo Usuario: "
    read nomeuser
    nomeuser="$(echo "$nomeuser" | sed 'y/áÁàÀãÃâÂéÉêÊíÍóÓõÕôÔúÚñÑçÇªº/aAaAaAaAeEeEiIoOoOoOuUnNcCao/')"
    nomeuser="$(echo "$nomeuser" | sed -e 's/[^a-z0-9 -]//ig')"
    if [[ -z "$nomeuser" ]]; then
      err_fun 1 && continue
    elif [[ "${nomeuser}" = "0" ]]; then
      return
    elif [[ "${#nomeuser}" -lt "4" ]]; then
      err_fun 2 && continue
    elif [[ "${#nomeuser}" -gt "12" ]]; then
      err_fun 3 && continue
    elif echo "${usuarios_ativos[@]}" | grep -qw "$nomeuser"; then
      err_fun 14 && continue
    fi
    break
  done

  local senhauser=""
  while true; do
    msg -ne "Contraseña Del Nuevo Usuario: "
    read senhauser
    senhauser="$(echo "$senhauser" | sed 'y/áÁàÀãÃâÂéÉêÊíÍóÓõÕôÔúÚñÑçÇªº/aAaAaAaAeEeEiIoOoOoOuUnNcCao/')"
    if [[ -z "$senhauser" ]]; then
      err_fun 4 && continue
    elif [[ "${#senhauser}" -lt "4" ]]; then
      err_fun 5 && continue
    elif [[ "${#senhauser}" -gt "12" ]]; then
      err_fun 6 && continue
    fi
    break
  done

  local diasuser=""
  while true; do
    msg -ne "Tiempo de Duración (días): "
    read diasuser
    if [[ -z "$diasuser" ]]; then
      err_fun 7 && continue
    elif [[ "$diasuser" != +([0-9]) ]]; then
      err_fun 8 && continue
    elif [[ "$diasuser" -gt "360" ]]; then
      err_fun 9 && continue
    fi
    break
  done

  local limiteuser=""
  while true; do
    msg -ne "Límite de Conexión: "
    read limiteuser
    if [[ -z "$limiteuser" ]]; then
      err_fun 11 && continue
    elif [[ "$limiteuser" != +([0-9]) ]]; then
      err_fun 12 && continue
    elif [[ "$limiteuser" -gt "999" ]]; then
      err_fun 13 && continue
    fi
    break
  done

  local newfile="n" ovpnauth="n"
  if dpkg --get-selections 2>/dev/null | grep -qw "openvpn" && [[ -e /etc/openvpn/openvpn-status.log ]]; then
    while [[ "${newfile:-}" != @(s|S|y|Y|n|N) ]]; do
      msg -ne "Crear Archivo OpenVPN? [S/N]: "
      read -e -i S newfile
    done
    if [[ "${newfile}" = @(s|S) ]]; then
      while [[ "${ovpnauth:-}" != @(s|S|y|Y|n|N) ]]; do
        msg -ne "Autenticación de usuario en el archivo? [S/N]: "
        read -e -i S ovpnauth
      done
    fi
  fi

  add_user "${nomeuser}" "${senhauser}" "${diasuser}" "${limiteuser}" "${newfile}" "${ovpnauth}"
  echo "${nomeuser}|${senhauser}" >> "${VPS_user}/passwd"
}

# =========================================================
# CREAR USUARIO TEMPORAL
# =========================================================
mktmpuser() {
  local name="" pass="" tmp=""

  while [[ -z "$name" ]]; do
    msg -ne " Nombre del usuario: "
    read name
    if [[ -z "$name" ]]; then
      tput cuu1 && tput dl1
      msg -ama " Escriba un nombre de usuario"
      sleep 2
      tput cuu1 && tput dl1
      unset name
      continue
    fi
  done

  if grep -w "${name}:" /etc/passwd | grep -vi "[a-z]${name}" | grep -v "[0-9]${name}" > /dev/null 2>&1; then
    tput cuu1 && tput dl1
    msg -verm2 " El usuario $name ya existe"
    sleep 2
    tput cuu1 && tput dl1
    return
  fi

  while [[ -z "$pass" ]]; do
    msg -ne " Contraseña: "
    read pass
    if [[ -z "$pass" ]]; then
      tput cuu1 && tput dl1
      msg -ama " Escriba una Contraseña"
      sleep 2
      tput cuu1 && tput dl1
      unset pass
      continue
    fi
  done

  while [[ -z "$tmp" ]]; do
    msg -ne " Duración en minutos: "
    read tmp
    if [[ -z "$tmp" ]]; then
      tput cuu1 && tput dl1
      msg -ama " Escriba un tiempo de duración"
      sleep 2
      tput cuu1 && tput dl1
      unset tmp
      continue
    fi
  done

  if [[ -z "${1:-}" ]]; then
    msg -ne " Aplicar a conf Default [S/N]: "
    read def
    if [[ "${def:-}" = @(s|S|y|Y) ]]; then
      echo -e "usuario=$name\nContraseña=$pass\nTiempo=$tmp" > "${Default}"
    fi
  fi

  useradd -M -s /bin/false -p "$(openssl passwd -6 "$pass")" "$name"

  local timer=$(( tmp * 60 ))
  cat > "/tmp/sn_tmp_${name}.sh" << TMPEOF
#!/bin/bash
sleep $timer
pkill -u $name 2>/dev/null
userdel --force $name 2>/dev/null
rm -f /tmp/sn_tmp_${name}.sh
exit 0
TMPEOF
  chmod +x "/tmp/sn_tmp_${name}.sh"
  nohup "/tmp/sn_tmp_${name}.sh" &>/dev/null &

  echo ""
  msg -bar
  echo -e "${Y}        【 ☬ USUARIO TEMPORAL CREADO ☬ 】${N}"
  msg -bar
  echo -e "${W}❍ 👤 Usuario:${N}     ${G}${name}${N}"
  echo -e "${W}❍ 🔐 Contraseña:${N}  ${G}${pass}${N}"
  echo -e "${W}❍ ⏱  Duración:${N}    ${Y}${tmp} minutos${N}"
  echo -e "${R}──────INFORMACION DEL VPS ──────${N}"
  echo -e "${W}› ip vps:${N}        ${Y}$(fun_ip)${N}"
  msg -bar
  read
  return
}

userTMP() {
  local tmp_f="${VPS_user}/userTMP"
  [[ ! -d "${tmp_f}" ]] && mkdir -p "${tmp_f}"
  Default="${tmp_f}/Default"
  if [[ ! -e "${Default}" ]]; then
    echo -e "usuario=VPS-SN\nContraseña=VPS-SN\nTiempo=15" > "${Default}"
  fi

  local name pass tmp
  name="$(grep "usuario" "${Default}" | cut -d "=" -f2)"
  pass="$(grep "Contraseña" "${Default}" | cut -d "=" -f2)"
  tmp="$(grep "Tiempo" "${Default}" | cut -d "=" -f2)"

  title "USUARIO TEMPORAL ⏱"
  print_center_bar "${W}Usuario Default${N}"
  msg -bar3
  echo -e " ${W}IP:${N}         ${Y}$(fun_ip)${N}"
  echo -e " ${W}Usuario:${N}    ${Y}${name}${N}"
  echo -e " ${W}Contraseña:${N} ${Y}${pass}${N}"
  echo -e " ${W}Duración:${N}   ${Y}${tmp} minutos${N}"
  msg -bar
  menu_func "APLICAR CONF DEFAULT" "CONF PERSONALIZADA"
  back
  local opcion
  opcion=$(selection_fun 2)
  case "$opcion" in
    1) mktmpuser "def" ;;
    2) unset name; unset pass; unset tmp; mktmpuser ;;
    0) return ;;
  esac
}

# =========================================================
# REMOVER USUARIO
# =========================================================
rm_user() {
  if userdel --force "$1" 2>/dev/null; then
    sed -i "/$1/d" "${VPS_user}/passwd" 2>/dev/null
    print_center -verd "[Removido]"
  else
    print_center -verm2 "[No Removido]"
  fi
}

remove_user() {
  clear
  local usuarios_ativos
  usuarios_ativos=('' $(mostrar_usuarios))

  title "REMOVER USUARIO 🗑"
  data_user
  back
  print_center -ama "Escriba o Seleccione un Usuario"
  msg -bar

  local selection=""
  while [[ -z "${selection}" ]]; do
    msg -ne "Seleccione Una Opción: " && read selection
    tput cuu1 && tput dl1
  done
  [[ "${selection}" = "0" ]] && return

  local usuario_del
  if [[ ! $(echo "${selection}" | grep -E '[^0-9]') ]]; then
    usuario_del="${usuarios_ativos[$selection]:-}"
  else
    usuario_del="$selection"
  fi

  [[ -z "$usuario_del" ]] && { msg -verm "Error, Usuario Inválido"; msg -bar; return 1; }
  echo "${usuarios_ativos[@]}" | grep -qw "$usuario_del" || { msg -verm "Error, Usuario Inválido"; msg -bar; return 1; }

  print_center -ama "Usuario Seleccionado: $usuario_del"
  pkill -u "$usuario_del" 2>/dev/null
  local droplim
  droplim=$(droppids | grep -w "$usuario_del" | awk '{print $2}')
  [[ -n "$droplim" ]] && kill -9 "$droplim" 2>/dev/null
  rm_user "$usuario_del"
  msg -bar
  sleep 3
}

# =========================================================
# RENOVAR USUARIO
# =========================================================
renew_user_fun() {
  local valid
  valid=$(date '+%C%y-%m-%d' -d " + $2 days")
  if chage -E "$valid" "$1" 2>/dev/null; then
    print_center -ama "Usuario Renovado Con Éxito"
  else
    print_center -verm2 "Error, Usuario no Renovado"
  fi
}

renew_user() {
  clear
  local usuarios_ativos
  usuarios_ativos=('' $(mostrar_usuarios))

  title "RENOVAR USUARIO ♻️"
  data_user
  back
  print_center -ama "Escriba o seleccione un Usuario"
  msg -bar

  local selection=""
  while [[ -z "${selection}" ]]; do
    msg -ne " Seleccione una Opción: " && read selection
    tput cuu1 && tput dl1
  done
  [[ "${selection}" = "0" ]] && return

  local useredit
  if [[ ! $(echo "${selection}" | grep -E '[^0-9]') ]]; then
    useredit="${usuarios_ativos[$selection]:-}"
  else
    useredit="$selection"
  fi

  [[ -z "$useredit" ]] && { msg -verm "Error, Usuario Inválido"; msg -bar; sleep 3; return 1; }
  echo "${usuarios_ativos[@]}" | grep -qw "$useredit" || { msg -verm "Error, Usuario Inválido"; msg -bar; sleep 3; return 1; }

  local diasuser=""
  while true; do
    msg -ne "Nuevo Tiempo de Duración de ${useredit}: "
    read diasuser
    if [[ -z "$diasuser" ]]; then
      echo -e '\n\n\n'; err_fun 7 && continue
    elif [[ "$diasuser" != +([0-9]) ]]; then
      echo -e '\n\n\n'; err_fun 8 && continue
    elif [[ "$diasuser" -gt "360" ]]; then
      echo -e '\n\n\n'; err_fun 9 && continue
    fi
    break
  done

  msg -bar
  renew_user_fun "${useredit}" "${diasuser}"
  msg -bar
  sleep 3
}

# =========================================================
# EDITAR USUARIO
# =========================================================
edit_user_fun() {
  local valid
  valid=$(date '+%C%y-%m-%d' -d " + $3 days")
  clear
  msg -bar
  if usermod -p "$(openssl passwd -6 "$2")" -e "$valid" -c "$4,$2" "$1" 2>/dev/null; then
    print_center -verd "Usuario Modificado Con Éxito"
  else
    print_center -verm2 "Error, Usuario no Modificado"
    msg -bar
    sleep 3
    return
  fi
  msg -bar
}

edit_user() {
  clear
  local usuarios_ativos
  usuarios_ativos=('' $(mostrar_usuarios))

  title "EDITAR USUARIO 📝"
  data_user
  back
  print_center -ama "Escriba o seleccione un Usuario"
  msg -bar

  local selection=""
  while [[ -z "${selection}" ]]; do
    msg -ne " Seleccione una Opción: " && read selection
    tput cuu1; tput dl1
  done
  [[ "${selection}" = "0" ]] && return

  local useredit
  if [[ ! $(echo "${selection}" | grep -E '[^0-9]') ]]; then
    useredit="${usuarios_ativos[$selection]:-}"
  else
    useredit="$selection"
  fi

  [[ -z "$useredit" ]] && { msg -verm "Error, Usuario Inválido"; msg -bar; return 1; }
  echo "${usuarios_ativos[@]}" | grep -qw "$useredit" || { msg -verm "Error, Usuario Inválido"; msg -bar; return 1; }

  local senhauser=""
  while true; do
    msg -ne "Usuario Seleccionado: " && echo -e "$useredit"
    msg -ne "Nueva Contraseña de ${useredit}: "
    read senhauser
    if [[ -z "$senhauser" ]]; then
      err_fun 4 && continue
    elif [[ "${#senhauser}" -lt "4" ]]; then
      err_fun 5 && continue
    elif [[ "${#senhauser}" -gt "12" ]]; then
      err_fun 6 && continue
    fi
    break
  done

  local diasuser=""
  while true; do
    msg -ne "Días de Duración de ${useredit}: "
    read diasuser
    if [[ -z "$diasuser" ]]; then
      err_fun 7 && continue
    elif [[ "$diasuser" != +([0-9]) ]]; then
      err_fun 8 && continue
    elif [[ "$diasuser" -gt "360" ]]; then
      err_fun 9 && continue
    fi
    break
  done

  local limiteuser=""
  while true; do
    msg -ne "Nuevo Límite de Conexión de ${useredit}: "
    read limiteuser
    if [[ -z "$limiteuser" ]]; then
      err_fun 11 && continue
    elif [[ "$limiteuser" != +([0-9]) ]]; then
      err_fun 12 && continue
    elif [[ "$limiteuser" -gt "999" ]]; then
      err_fun 13 && continue
    fi
    break
  done

  edit_user_fun "${useredit}" "${senhauser}" "${diasuser}" "${limiteuser}"

  # Mostrar info completa del usuario editado
  show_user_info "$useredit" "$senhauser" "$diasuser" "$limiteuser"
}

# =========================================================
# ELIMINAR TODOS LOS USUARIOS
# =========================================================
eliminar_all() {
  title "⚠️ ELIMINAR TODOS LOS USUARIOS ⚠️"
  msg -ne " ¿Está seguro? [S/N]: "
  read opcion
  [[ "${opcion}" != @(S|s) ]] && return 1

  service dropbear stop &>/dev/null
  service sshd stop &>/dev/null
  service ssh stop &>/dev/null
  service stunnel4 stop &>/dev/null
  service squid stop &>/dev/null

  local cat_users
  cat_users=$(grep 'home' /etc/passwd | grep 'false' | grep -v 'syslog' | grep -v "hwid" | grep -v "token")

  for user in $(echo "$cat_users" | awk -F ':' '{print $1}'); do
    local userpid
    userpid=$(ps -u "$user" -o pid= 2>/dev/null | head -1)
    [[ -n "$userpid" ]] && kill "$userpid" 2>/dev/null
    userdel --force "$user" 2>/dev/null
    local user2
    user2=$(printf '%-15s' "$user")
    echo -e " $(msg -azu "USUARIO:") $(msg -ama "$user2")$(msg -verm2 "Eliminado")"
  done

  service sshd restart &>/dev/null
  service ssh restart &>/dev/null
  service dropbear start &>/dev/null
  service stunnel4 start &>/dev/null
  service squid restart &>/dev/null

  msg -bar
  print_center -ama "USUARIOS ELIMINADOS"
  enter
  return 1
}

# =========================================================
# MONITOR DE USUARIOS CONECTADOS
# =========================================================
UDP_LOG_FILE="/var/log/udp-custom.log"

extract_users_from_json_log() {
  local file="$1"
  [[ ! -f "$file" ]] && return 1
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if command -v jq >/dev/null 2>&1; then
      local user ip
      user=$(echo "$line" | jq -r 'try(.user // .username // .auth.user // empty)' 2>/dev/null || echo "")
      ip=$(echo "$line" | jq -r 'try(.remote // .ip // .addr // .client_ip // empty)' 2>/dev/null || echo "")
      if [[ -n "$user" && "$user" != "null" ]]; then
        echo "${user}|${ip:-"-"}"
      fi
    fi
  done < "$file"
  return 0
}

extract_users_from_text_log() {
  local file="$1"
  [[ ! -f "$file" ]] && return 1
  grep -E -i "auth|authenticated|login|new connection|accepted|connect|client|username|user" "$file" 2>/dev/null | while IFS= read -r line; do
    local ip user
    ip=$(echo "$line" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n1 || true)
    user=$(echo "$line" | sed -nE 's/.*[Uu]sername[=:\ ]*"?([A-Za-z0-9._-]+)"?.*/\1/p' || true)
    [[ -z "$user" ]] && user=$(echo "$line" | sed -nE 's/.*[Uu]ser[=:\ ]*"?([A-Za-z0-9._-]+)"?.*/\1/p' || true)
    [[ -z "$user" ]] && user=$(echo "$line" | sed -nE 's/.*client[ =\[]*"?([A-Za-z0-9._-]+)"?.*/\1/p' || true)
    [[ -n "$user" ]] && echo "${user}|${ip:-"-"}"
  done
  return 0
}

build_udp_user_list() {
  local file="$UDP_LOG_FILE"
  [[ ! -f "$file" ]] && return 1
  if command -v jq >/dev/null 2>&1; then
    extract_users_from_json_log "$file" 2>/dev/null
  fi
  extract_users_from_text_log "$file" 2>/dev/null
}

sshmonitor() {
  clear
  msg -bar
  echo -e "${Y}           📡 MONITOR DE USUARIOS SSH / VPN / UDP 📡${N}"
  echo -e "${R}────────────────────────── / / / ──────────────────────────${N}"

  printf " %-14s %-12s %-18s %-10s\n" "USUARIO" "ESTADO" "CONEXIONES(L/UDP)" "TIEMPO"
  echo -e "${R}────────────────────────── / / / ──────────────────────────${N}"

  local UDP_PORT=36712
  if [[ -f /root/udp/config.json ]] && command -v jq >/dev/null 2>&1; then
    local porttmp
    porttmp=$(jq -r '.listen // empty' "/root/udp/config.json" 2>/dev/null | sed 's/://')
    [[ -n "$porttmp" ]] && UDP_PORT="$porttmp"
  fi

  declare -A UDP_USER_COUNT
  declare -A UDP_USER_IPS

  if [[ -f "$UDP_LOG_FILE" ]]; then
    while IFS= read -r entry; do
      [[ -z "$entry" ]] && continue
      local user="${entry%%|*}"
      local ip="${entry#*|}"
      [[ -z "$user" ]] && continue
      UDP_USER_COUNT["$user"]=$(( ${UDP_USER_COUNT["$user"]:-0} + 1 ))
      local existing="${UDP_USER_IPS["$user"]:-}"
      if [[ -n "$ip" && "$ip" != "-" && "$existing" != *"$ip"* ]]; then
        UDP_USER_IPS["$user"]="${existing} ${ip}"
      fi
    done < <(build_udp_user_list 2>/dev/null | sort -u)
  fi

  local cat_users
  cat_users=$(awk -F: '$3>=1000 && $7 ~ /false/ {print}' /etc/passwd)

  for i in $(echo "$cat_users" | awk -F: '{print $1}'); do
    local user="$i"
    local s2ssh sshd_count drop ovp udp_proc conex timerr estado_txt estado_color

    s2ssh=$(echo "$cat_users" | grep -w "$i" | awk -F: '{print $5}' | cut -d',' -f1)
    [[ -z "$s2ssh" ]] && s2ssh=0

    sshd_count=$(ps -u "$user" 2>/dev/null | grep -c sshd || echo 0)
    drop=$(ps aux | grep -i dropbear | grep -w "$user" | grep -v grep | wc -l)

    ovp=0
    [[ -e /etc/openvpn/openvpn-status.log ]] && ovp=$(grep -c ",$user," /etc/openvpn/openvpn-status.log 2>/dev/null || echo 0)

    udp_proc=0
    if [[ -n "${UDP_USER_COUNT["$user"]:-}" ]]; then
      udp_proc=${UDP_USER_COUNT["$user"]}
    else
      udp_proc=$(ps -u "$user" 2>/dev/null | grep -E "udp-custom|badvpn" | grep -v grep | wc -l)
    fi

    conex=$((sshd_count + drop + ovp + udp_proc))

    if [[ $conex -gt 0 ]]; then
      local pid
      pid=$(ps -u "$user" -o pid= 2>/dev/null | head -n 1 | xargs)
      if [[ -n "$pid" ]]; then
        timerr=$(ps -o etime= -p "$pid" 2>/dev/null | sed 's/^ *//')
        [[ ${#timerr} -lt 8 ]] && timerr="00:$timerr"
      else
        timerr="00:00:00"
      fi
    else
      timerr="00:00:00"
    fi

    estado_txt=$( [[ $conex -eq 0 ]] && echo "OFFLINE" || echo "ONLINE" )
    [[ $conex -eq 0 ]] && estado_color=$R || estado_color=$G

    printf " ${Y}%-14s${N} ${estado_color}%-12s${N} ${G}%-18s${N} ${Y}%-10s${N}\n" \
      "$user" "$estado_txt" "$conex ($s2ssh/$udp_proc)" "$timerr"
  done

  # Usuarios UDP sin cuenta del sistema
  if [[ -f "$UDP_LOG_FILE" ]]; then
    declare -A seen_sys
    for u in $(echo "$cat_users" | awk -F: '{print $1}'); do seen_sys["$u"]=1; done

    local extra_users=()
    for u in "${!UDP_USER_COUNT[@]}"; do
      [[ -z "${seen_sys["$u"]:-}" ]] && extra_users+=("$u|${UDP_USER_IPS[$u]:-}")
    done

    if ((${#extra_users[@]} > 0)); then
      echo -e "${R}────────────────────────── / / / ──────────────────────────${N}"
      echo -e "${W}Usuarios UDP detectados (sin cuenta sistema):${N}"
      for e in "${extra_users[@]}"; do
        local eu="${e%%|*}"
        local eips="${e#*|}"
        echo -e "  ${Y}${eu}${N}  IPs:${G}${eips}${N}  Conexiones:${C}${UDP_USER_COUNT[$eu]:-0}${N}"
      done
    fi
  fi

  if systemctl list-units --type=service --state=running 2>/dev/null | grep -q "udp-custom"; then
    local udp_total
    udp_total=$(ss -u -a 2>/dev/null | grep -cE ":${UDP_PORT}\b" || echo 0)
    echo -e "${R}────────────────────────── / / / ──────────────────────────${N}"
    echo -e "${W} UDP CUSTOM ACTIVO | PUERTO: ${Y}$UDP_PORT${W} | CONEXIONES TOTALES: ${G}$udp_total${N}"
  fi

  msg -bar
  echo -e "${Y}            ►► Presione ENTER para continuar ◄◄${N}"
  read
}

# =========================================================
# DETALLES DE USUARIOS
# =========================================================
detail_user() {
  clear
  local usuarios_ativos
  usuarios_ativos=('' $(mostrar_usuarios))

  if [[ ${#usuarios_ativos[@]} -le 1 ]]; then
    msg -bar
    print_center -verm2 "Ningún usuario registrado"
    msg -bar
    sleep 3
    return
  fi

  title "DETALLES DE USUARIOS 🔎"
  data_user
  msg -bar
  echo -e "${Y}            ►► Presione ENTER para continuar ◄◄${N}"
  read
}

# =========================================================
# BLOQUEAR / DESBLOQUEAR USUARIO
# =========================================================
block_user() {
  clear
  local usuarios_ativos
  usuarios_ativos=('' $(mostrar_usuarios))

  title "BLOQUEAR / DESBLOQUEAR USUARIO 🔒"
  data_user
  back
  print_center -ama "Escriba o Seleccione Un Usuario"
  msg -bar

  local selection=""
  while [[ "${selection}" = "" ]]; do
    msg -ne "Seleccione: " && read selection
    tput cuu1 && tput dl1
  done
  [[ "${selection}" = "0" ]] && return

  local usuario_del
  if [[ ! $(echo "${selection}" | grep -E '[^0-9]') ]]; then
    usuario_del="${usuarios_ativos[$selection]:-}"
  else
    usuario_del="$selection"
  fi

  [[ -z "$usuario_del" ]] && { msg -verm "Error, Usuario Inválido"; msg -bar; return 1; }
  echo "${usuarios_ativos[@]}" | grep -qw "$usuario_del" || { msg -verm "Error, Usuario Inválido"; msg -bar; return 1; }

  msg -ne "   Usuario: $usuario_del >>>> "

  if [[ $(passwd --status "$usuario_del" | cut -d ' ' -f2) = "P" ]]; then
    pkill -u "$usuario_del" 2>/dev/null
    local droplim
    droplim=$(droppids | grep -w "$usuario_del" | awk '{print $2}')
    [[ -n "$droplim" ]] && kill -9 "$droplim" 2>/dev/null
    usermod -L "$usuario_del" 2>/dev/null
    sleep 2
    msg -verm2 "Bloqueado 🔒"
  else
    usermod -U "$usuario_del" 2>/dev/null
    sleep 2
    msg -verd "Desbloqueado 🔓"
  fi
  msg -bar
  sleep 3
}

# =========================================================
# REMOVER USUARIOS VENCIDOS
# =========================================================
rm_vencidos() {
  title "REMOVER USUARIOS VENCIDOS"
  print_center -ama "Removerá todos los usuarios SSH expirados"
  msg -bar
  msg -ne " Continuar [S/N]: "
  read opcion
  tput cuu1 && tput dl1
  [[ "$opcion" != @(s|S|y|Y) ]] && return

  local DataVPS
  DataVPS=$(date +%s)

  while read -r user; do
    [[ -z "$user" ]] && continue
    local DataUser
    DataUser=$(chage -l "$user" | sed -n '4p' | awk -F ': ' '{print $2}')
    [[ "$DataUser" = @(never|nunca) ]] && continue
    local DataSEC
    DataSEC=$(date +%s --date="$DataUser")

    if [[ "$DataSEC" -lt "$DataVPS" ]]; then
      pkill -u "$user" 2>/dev/null
      local droplim
      droplim=$(droppids | grep -w "$user" | awk '{print $2}')
      [[ -n "$droplim" ]] && kill -9 "$droplim" 2>/dev/null
      userdel "$user" 2>/dev/null
      print_center -ama "$user Expirado (Removido)"
      sleep 1
    fi
  done <<< "$(mostrar_usuarios)"
  enter
}

# =========================================================
# LIMITADOR DE CUENTAS
# =========================================================
numero='^[0-9]+$'

limiter() {
  ltr() {
    clear
    msg -bar
    for i in $(atq 2>/dev/null | awk '{print $1}'); do
      if [[ -n "$(at -c "$i" 2>/dev/null | grep 'limitador.sh')" ]]; then
        atrm "$i" 2>/dev/null
        sed -i '/limitador.sh/d' /var/spool/cron/crontabs/root 2>/dev/null
        print_center -verd "Limitador detenido"
        msg -bar
        echo -e "${Y}            ►► Presione ENTER para continuar ◄◄${N}"
        read
        return
      fi
    done

    print_center_bar "$(msg -ama "CONF LIMITADOR")"
    msg -bar
    print_center -ama "Bloquea usuarios cuando exceden"
    print_center -ama "el número máximo de conexiones"
    msg -bar

    local opcion=""
    while [[ -z "$opcion" ]]; do
      msg -ne " Ejecutar limitador cada: "
      read opcion
      if [[ ! $opcion =~ $numero ]]; then
        tput cuu1 && tput dl1
        print_center -verm2 "Solo se admiten números"
        sleep 2; tput cuu1 && tput dl1
        unset opcion && continue
      elif [[ $opcion -le 0 ]]; then
        tput cuu1 && tput dl1
        print_center -verm2 "Tiempo mínimo 1 minuto"
        sleep 2; tput cuu1 && tput dl1
        unset opcion && continue
      fi
      tput cuu1 && tput dl1
      echo -e "$(msg -ne " Ejecutar limitador cada:") $(msg -verd "$opcion minutos")"
      echo "$opcion" > "${VPS_user}/limit"
    done

    msg -bar
    print_center -ama "Los usuarios bloqueados por el limitador"
    print_center -ama "serán desbloqueados automáticamente"
    print_center -ama "(ingresa 0 para desbloqueo manual)"
    msg -bar

    local opcion2=""
    while [[ -z "$opcion2" ]]; do
      msg -ne " Desbloquear user cada: "
      read opcion2
      if [[ ! $opcion2 =~ $numero ]]; then
        tput cuu1 && tput dl1
        print_center -verm2 "Solo se admiten números"
        sleep 2; tput cuu1 && tput dl1
        unset opcion2 && continue
      fi
      tput cuu1 && tput dl1
      [[ $opcion2 -le 0 ]] && echo -e "$(msg -ne " Desbloqueo:") $(msg -verd "manual")" \
        || echo -e "$(msg -ne " Desbloquear user cada:") $(msg -verd "$opcion2 minutos")"
      echo "$opcion2" > "${VPS_user}/unlimit"
    done

    nohup "${VPS_inst}/limitador.sh" &>/dev/null &
    msg -bar
    print_center -verd "Limitador en ejecución"
    msg -bar
    echo -e "${Y}            ►► Presione ENTER para continuar ◄◄${N}"
    read
  }

  l_exp() {
    clear
    msg -bar
    local l_cron
    l_cron=$(grep -w 'limitador.sh' /var/spool/cron/crontabs/root 2>/dev/null | grep -w 'ssh')
    if [[ -z "$l_cron" ]]; then
      echo '@daily /etc/SN/install/limitador.sh --ssh' >> /var/spool/cron/crontabs/root
      print_center -verd "Limitador de expirados programado\nSe ejecutará todos los días a las 00hs"
      enter
      return
    else
      sed -i '/limitador.sh --ssh/d' /var/spool/cron/crontabs/root 2>/dev/null
      print_center -verm2 "Limitador de expirados detenido"
      enter
      return
    fi
  }

  log_lim() {
    clear
    msg -bar
    print_center_bar "$(msg -ama "REGISTRO DEL LIMITADOR")"
    msg -bar
    [[ ! -e "${VPS_user}/limit.log" ]] && touch "${VPS_user}/limit.log"
    if [[ -z "$(cat "${VPS_user}/limit.log")" ]]; then
      print_center -ama "No hay registro de limitador"
      msg -bar
      sleep 2
      return
    fi
    cat "${VPS_user}/limit.log"
    msg -bar
    print_center -ama "►► ENTER para continuar | 0 para limpiar ◄◄"
    local opcion
    read opcion
    [[ "$opcion" = "0" ]] && echo "" > "${VPS_user}/limit.log"
  }

  local lim_e
  [[ $(grep -w 'limitador.sh' /var/spool/cron/crontabs/root 2>/dev/null | grep -w 'ssh') ]] \
    && lim_e=$(msg -verd "[ON]") || lim_e=$(msg -verm2 "[OFF]")

  title "🔒 LIMITADOR DE CUENTAS 🔒"
  menu_func "LIMITADOR DE CONEXIONES" \
            "LIMITADOR DE EXPIRADOS $lim_e" \
            "LOG DEL LIMITADOR"
  back
  msg -ne " Opción: "
  read opcion
  case "$opcion" in
    1) ltr ;;
    2) l_exp ;;
    3) log_lim ;;
    0) return ;;
  esac
}

# =========================================================
# MENÚ PRINCIPAL SSH
# =========================================================
while :; do
  local_lim=$(msg -verm2 "[OFF]")
  for i in $(atq 2>/dev/null | awk '{print $1}'); do
    if [[ -n "$(at -c "$i" 2>/dev/null | grep 'limitador.sh')" ]]; then
      local_lim=$(msg -verd "[ON]")
    fi
  done

  title "ADMINISTRACIÓN DE USUARIOS SSH"

  msg -bar3
  menu_func \
    "NUEVO USUARIO SSH ✏️" \
    "CREAR USUARIO TEMPORAL ⏱" \
    "$(msg -verm2 "REMOVER USUARIO") 🗑" \
    "$(msg -verd "RENOVAR USUARIO") ♻️" \
    "EDITAR USUARIO 📝" \
    "BLOQ/DESBLOQ USUARIO 🔒" \
    "$(msg -verd "DETALLES DE USUARIOS") 🔎" \
    "MONITOR DE USUARIOS 📡" \
    "🔒 $(msg -ama "LIMITADOR DE CUENTAS") 🔒 ${local_lim}" \
    "ELIMINAR USUARIOS VENCIDOS" \
    "⚠️ $(msg -verm2 "ELIMINAR TODOS LOS USUARIOS") ⚠️"
  back

  selection=$(selection_fun 11)
  case "${selection}" in
    0)  break ;;
    1)  new_user ;;
    2)  userTMP ;;
    3)  remove_user ;;
    4)  renew_user ;;
    5)  edit_user ;;
    6)  block_user ;;
    7)  detail_user ;;
    8)  sshmonitor ;;
    9)  limiter ;;
    10) rm_vencidos ;;
    11) eliminar_all ;;
  esac
done
