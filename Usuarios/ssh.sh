#!/bin/bash
# ================= AUTONOMIA SSH.SH =================
# >>> BLOQUE AUTONOMÍA (RUTAS SN) <<<
VPS_user="/etc/SN"
VPS_inst="/etc/SN/install"
USRdatabase="/etc/SN/usuarios"
mkdir -p "$VPS_user" "$VPS_inst" "$USRdatabase"
# ================= COLORES SINNOMBRE =================
R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
B='\033[0;34m'
M='\033[0;35m'
C='\033[0;36m'
W='\033[1;37m'
N='\033[0m'
NC='\033[0m'

# ================= MENSAJES =================
msg() {
  case $1 in
    -bar) echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}" ;;
    -bar3) echo -e "${R}─────────────────────────── / / / ──────────────────────────${N}" ;;
    -verd) echo -e "${G}$2${N}" ;;
    -verm|-verm2) echo -e "${R}$2${N}" ;;
    -ama) echo -e "${Y}$2${N}" ;;
    -azu|-nazu) echo -e "${C}$2${N}" ;;
    -nama) echo -ne "${Y}$2${N}" ;;
    -ne) echo -ne "$2" ;;
    *) echo -e "$*" ;;
  esac
}

# ================= TITULO =================
title() {
  clear
  msg -bar
  print_center "${W}$*${N}"
  msg -bar
}

# TEXTO CENTRADO EN BARRA
print_center_bar() {
  local text="$1"
  local bar_len=50  # Longitud de la barra
  local len=${#text}
  local padding=$(( (bar_len - len) / 2 ))
  [[ $padding -gt 0 ]] && printf '%*s' $padding ''
  echo -e "$text"
}

# TEXTO CENTRADO EN TERMINAL
print_center() {
  local text="$1"
  local cols=$(tput cols 2>/dev/null || echo 80)
  local len=${#text}
  local padding=$(( (cols - len) / 2 ))
  [[ $padding -gt 0 ]] && printf '%*s' $padding ''
  echo -e "$text"
}

# BACK
back() {
  msg -bar3
  echo -e "${R}[${Y}0${R}]${N}  ${C}Volver${N}"
  msg -bar3
}
# MENU
menu_func() {
  local i=1
  for opt in "$@"; do
    echo -e "${R}[${Y}$i${R}]${N}  ${C}$opt${N}"
    ((i++))
  done
}
# SELECCION
selection_fun() {
  local max=$1
  local opt
  while true; do
    read -p " Opción: " opt
    [[ "$opt" =~ ^[0-9]+$ ]] && [[ "$opt" -ge 0 && "$opt" -le $max ]] && {
      echo "$opt"
      return
    }
  done
}

# TRADUCCION (dummy)
fun_trans() {
  echo "$*"
}

# IP SERVER
fun_ip() {
  curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}'
}

# DROPBEAR PIDS
droppids() {
  ps aux | grep dropbear | grep -v grep | awk '{print $2, $1}'
}

# ENTER
enter() {
  read -p " Presione ENTER para continuar"
}

# ================= FIN AUTONOMIA =================

USRdatabase="${VPS_user}/VPSuser"
[[ ! -d ${VPS_user}/B-VPSuser ]] && mkdir ${VPS_user}/B-VPSuser

err_fun(){
  case $1 in
    1)tput cuu1; tput dl1 && msg -verm "$(fun_trans "Usuario Nulo")"; sleep 2s; tput cuu1; tput dl1;;
    2)tput cuu1; tput dl1 && msg -verm "$(fun_trans "Usuario con nombre muy corto")"; sleep 2s; tput cuu1; tput dl1;;
    3)tput cuu1; tput dl1 && msg -verm "$(fun_trans "Usuario con nombre muy grande")"; sleep 2s; tput cuu1; tput dl1;;
    4)tput cuu1; tput dl1 && msg -verm "$(fun_trans "Contraseña Nula")"; sleep 2s; tput cuu1; tput dl1;;
    5)tput cuu1; tput dl1 && msg -verm "$(fun_trans "Contraseña muy corta")"; sleep 2s; tput cuu1; tput dl1;;
    6)tput cuu1; tput dl1 && msg -verm "$(fun_trans "Contraseña muy grande")"; sleep 2s; tput cuu1; tput dl1;;
    7)tput cuu1; tput dl1 && msg -verm "$(fun_trans "Duracion Nula")"; sleep 2s; tput cuu1; tput dl1;;
    8)tput cuu1; tput dl1 && msg -verm "$(fun_trans "Duracion invalida utilize numeros")"; sleep 2s; tput cuu1; tput dl1;;
    9)tput cuu1; tput dl1 && msg -verm "$(fun_trans "Duracion maxima y de un año")"; sleep 2s; tput cuu1; tput dl1;;
    11)tput cuu1; tput dl1 && msg -verm "$(fun_trans "Limite Nulo")"; sleep 2s; tput cuu1; tput dl1;;
    12)tput cuu1; tput dl1 && msg -verm "$(fun_trans "Limite invalido utilize numeros")"; sleep 2s; tput cuu1; tput dl1;;
    13)tput cuu1; tput dl1 && msg -verm "$(fun_trans "Limite maximo de 999")"; sleep 2s; tput cuu1; tput dl1;;
    14)tput cuu1; tput dl1 && msg -verm "$(fun_trans "Usuario Ya Existe")"; sleep 2s; tput cuu1; tput dl1;;
  esac
}

# Open VPN
newclient(){
  newfile=""
  ovpnauth=""
  while [[ ${newfile:-} != @(s|S|y|Y|n|N) ]]; do
    msg -bar
    read -p "Crear Archivo OpenVPN? [S/N]: " -e -i S newfile
    tput cuu1 && tput dl1
  done

  if [[ ${newfile} = @(s|S) ]]; then
    #Generates the custom client.ovpn
    rm -rf /etc/openvpn/easy-rsa/pki/reqs/$1.req
    rm -rf /etc/openvpn/easy-rsa/pki/issued/$1.crt
    rm -rf /etc/openvpn/easy-rsa/pki/private/$1.key
    cd /etc/openvpn/easy-rsa/
    ./easyrsa build-client-full $1 nopass > /dev/null 2>&1
    cd

    cp /etc/openvpn/client-common.txt ~/$1.ovpn
    echo "<ca>" >> ~/$1.ovpn
    cat /etc/openvpn/easy-rsa/pki/ca.crt >> ~/$1.ovpn
    echo "</ca>" >> ~/$1.ovpn
    echo "<cert>" >> ~/$1.ovpn
    cat /etc/openvpn/easy-rsa/pki/issued/$1.crt >> ~/$1.ovpn
    echo "</cert>" >> ~/$1.ovpn
    echo "<key>" >> ~/$1.ovpn
    cat /etc/openvpn/easy-rsa/pki/private/$1.key >> ~/$1.ovpn
    echo "</key>" >> ~/$1.ovpn
    echo "<tls-auth>" >> ~/$1.ovpn
    cat /etc/openvpn/ta.key >> ~/$1.ovpn
    echo "</tls-auth>" >> ~/$1.ovpn

    while [[ ${ovpnauth:-} != @(s|S|y|Y|n|N) ]]; do
      read -p "$(fun_trans "Colocar autenticacion de usuario en el archivo")? [S/N]: " -e -i S ovpnauth
      tput cuu1 && tput dl1
    done
    [[ ${ovpnauth} = @(s|S) ]] && sed -i "s;auth-user-pass;<auth-user-pass>\n$1\n$2\n</auth-user-pass>;g" ~/$1.ovpn
    cd $HOME
    zip ./$1.zip ./$1.ovpn > /dev/null 2>&1
    rm ./$1.ovpn > /dev/null 2>&1

    echo -e "\033[1;31m$(fun_trans "Archivo creado"): ($HOME/$1.zip)"
 fi
}

data_user(){
        cat_users=$(cat "/etc/passwd"|grep 'home'|grep 'false'|grep -v 'syslog')
        [[ -z "$(echo "${cat_users}"|awk -F ':' '{print $5}'|cut -d ',' -f1|grep -v 'hwid'|grep -v 'token'|head -1)" ]] && print_center "$(msg -verm2 "$(fun_trans "NO HAY USUARIOS SSH REGISTRADOS")")"[...]
        dat_us=$(printf '%-13s%-14s%-10s%-4s%-6s%s' 'Usuario' 'Contraseña' 'Fecha' 'Dia' 'Limit' 'Statu')
        msg -azu "  $dat_us"
        msg -bar

        local i=1
        for u in `echo "${cat_users}"|awk -F ':' '{print $1}'`; do

                fix_hwid_token=$(echo "${cat_users}"|grep -w "$u"|awk -F ':' '{print $5}'|cut -d ',' -f1) && [[ "${fix_hwid_token}" = @(hwid|token) ]] && continue

                fecha=$(chage -l "$u"|sed -n '4p'|awk -F ': ' '{print $2}')

                mes_dia=$(echo $fecha|awk -F ',' '{print $1}'|sed 's/ //g')
                ano=$(echo $fecha|awk -F ', ' '{printf $2}'|cut -c 3-)
                us=$(printf '%-12s' "$u")

                pass=$(cat "/etc/passwd"|grep -w "$u"|awk -F ':' '{print $5}'|cut -d ',' -f2)
                [[ "${#pass}" -gt '12' ]] && pass="Desconosida"
                pass="$(printf '%-12s' "$pass")"

                unset stat
                if [[ $(passwd --status $u|cut -d ' ' -f2) = "P" ]]; then
                        stat="$(msg -verd "ULK")"
                else
                        stat="$(msg -verm2 "LOK")"
                fi

                Limit=$(cat "/etc/passwd"|grep -w "$u"|awk -F ':' '{print $5}'|cut -d ',' -f1)
                [[ "${#Limit}" = "1" ]] && Limit=$(printf '%2s%-4s' "$Limit") || Limit=$(printf '%-6s' "$Limit")

                echo -ne "$(msg -verd "$i")$(msg -verm2 "-")$(msg -azu "${us}") $(msg -azu "${pass}")"
                if [[ $(echo $fecha|awk '{print $2}') = "" ]]; then
                        exp="$(printf '%8s%-2s' '[X]')"
                        exp+="$(printf '%-6s' '[X]')"
                        echo " $(msg -verm2 "$fecha")$(msg -verd "$exp")$(echo -e "$stat")"        
                else
                        if [[ $(date +%s) -gt $(date '+%s' -d "${fecha}") ]]; then
                                exp="$(printf '%-5s' "Exp")"
                                echo " $(msg -verm2 "$mes_dia/$ano")  $(msg -verm2 "$exp")$(msg -ama "$Limit")$(echo -e "$stat")"
                        else
                                EXPTIME="$(($(($(date '+%s' -d "${fecha}") - $(date +%s))) / 86400))"
                                [[ "${#EXPTIME}" = "1" ]] && exp="$(printf '%2s%-3s' "$EXPTIME")" || exp="$(printf '%-5s' "$EXPTIME")"
                                echo " $(msg -verm2 "$mes_dia/$ano")  $(msg -verd "$exp")$(msg -ama "$Limit")$(echo -e "$stat")"
                        fi
                fi

                ((i++))
        done
}

#======CREAR NUEVO USUARIO===========
add_user(){
  Fecha=`date +%d-%m-%y-%R`
  [[ $(cat /etc/passwd |grep $1: |grep -vi [a-z]$1 |grep -v [0-9]$1 > /dev/null) ]] && return 1
  valid=$(date '+%C%y-%m-%d' -d " +$3 days")
  clear
  msg -bar

  system=$(cat -n /etc/issue |grep 1 |cut -d ' ' -f6,7,8 |sed 's/1//' |sed 's/      //')
  distro=$(echo "$system"|awk '{print $1}')
  vercion=$(echo $system|awk '{print $2}'|cut -d '.' -f1)

  if [[ ${distro} = @(Ubuntu|Debian) ]]; then
    if [[ ${vercion} = "16" ]]; then
      pass=$(openssl passwd -1 $2)
    else
      pass=$(openssl passwd -6 $2)
    fi
  else
    pass=$(openssl passwd -6 $2)  # Default
  fi

  if useradd -M -s /bin/false -e ${valid} -K PASS_MAX_DAYS=$3 -p ${pass} -c $4,$2 $1 ; then

    if [[ $5 = @(s|S) ]]; then
      rm -rf /etc/openvpn/easy-rsa/pki/reqs/$1.req
      rm -rf /etc/openvpn/easy-rsa/pki/issued/$1.crt
      rm -rf /etc/openvpn/easy-rsa/pki/private/$1.key
      cd /etc/openvpn/easy-rsa/
      ./easyrsa build-client-full $1 nopass > /dev/null 2>&1
      cd
      cp /etc/openvpn/client-common.txt ~/$1.ovpn
      echo "<ca>" >> ~/$1.ovpn
      cat /etc/openvpn/easy-rsa/pki/ca.crt >> ~/$1.ovpn
      echo "</ca>" >> ~/$1.ovpn
      echo "<cert>" >> ~/$1.ovpn
      cat /etc/openvpn/easy-rsa/pki/issued/$1.crt >> ~/$1.ovpn
      echo "</cert>" >> ~/$1.ovpn
      echo "<key>" >> ~/$1.ovpn
      cat /etc/openvpn/easy-rsa/pki/private/$1.key >> ~/$1.ovpn
      echo "</key>" >> ~/$1.ovpn
      echo "<tls-auth>" >> ~/$1.ovpn
      cat /etc/openvpn/ta.key >> ~/$1.ovpn
      echo "</tls-auth>" >> ~/$1.ovpn

      [[ $6 = @(s|S) ]] && sed -i "s;auth-user-pass;<auth-user-pass>\n$1\n$2\n</auth-user-pass>;g" ~/$1.ovpn
      cd $HOME
      zip ./$1.zip ./$1.ovpn > /dev/null 2>&1
      rm ./$1.ovpn > /dev/null 2>&1

      zip_ovpn="$HOME/$1.zip"

    fi

          print_center "$(msg -verd "$(fun_trans "Usuario Creado con Exito")")"
  else
          print_center "$(msg -verm2 "$(fun_trans "Error, Usuario no creado")")"
          msg -bar
          sleep 3
          return
  fi
  msg -bar
}

mostrar_usuarios(){
  for u in `cat /etc/passwd|grep 'home'|grep 'false'|grep -v 'syslog'|grep -v 'hwid'|grep -v 'token'|awk -F ':' '{print $1}'`; do
    echo "$u"
  done
}

new_user(){
  clear
  usuarios_ativos=('' $(mostrar_usuarios))
  msg -bar
  print_center_bar "$(msg -ama "$(fun_trans "CREAR USUARIOS")")"
  msg -bar
  data_user
  back

  while true; do
    msg -ne "$(fun_trans "Nombre Del Nuevo Usuario"): "
    read nomeuser
    nomeuser="$(echo $nomeuser|sed 'y/áÁàÀãÃâÂéÉêÊíÍóÓõÕôÔúÚñÑçÇªº/aAaAaAaAeEeEiIoOoOoOuUnNcCao/')"
    nomeuser="$(echo $nomeuser|sed -e 's/[^a-z0-9 -]//ig')"
    if [[ -z $nomeuser ]]; then
      err_fun 1 && continue
    elif [[ "${nomeuser}" = "0" ]]; then
      return
    elif [[ "${#nomeuser}" -lt "4" ]]; then
      err_fun 2 && continue
    elif [[ "${#nomeuser}" -gt "12" ]]; then
      err_fun 3 && continue
    elif [[ "$(echo ${usuarios_ativos[@]}|grep -w "$nomeuser")" ]]; then
      err_fun 14 && continue
    fi
    break
  done

  while true; do
    msg -ne "$(fun_trans "Contraseña Del Nuevo Usuario")"
    read -p ": " senhauser
    senhauser="$(echo $senhauser|sed 'y/áÁàÀãÃâÂéÉêÊíÍóÓõÕôÔúÚñÑçÇªº/aAaAaAaAeEeEiIoOoOoOuUnNcCao/')"
    if [[ -z $senhauser ]]; then
      err_fun 4 && continue
    elif [[ "${#senhauser}" -lt "4" ]]; then
      err_fun 5 && continue
    elif [[ "${#senhauser}" -gt "12" ]]; then
      err_fun 6 && continue
    fi
    break
  done

  while true; do
    msg -ne "$(fun_trans "Tiempo de Duracion del Nuevo Usuario")"
    read -p ": " diasuser
    if [[ -z "$diasuser" ]]; then
      err_fun 7 && continue
    elif [[ "$diasuser" != +([0-9]) ]]; then
      err_fun 8 && continue
    elif [[ "$diasuser" -gt "360" ]]; then
      err_fun 9 && continue
    fi 
    break
  done

  while true; do
    msg -ne "$(fun_trans "Limite de Conexion del Nuevo Usuario")"
    read -p ": " limiteuser
    if [[ -z "$limiteuser" ]]; then
      err_fun 11 && continue
    elif [[ "$limiteuser" != +([0-9]) ]]; then
      err_fun 12 && continue
    elif [[ "$limiteuser" -gt "999" ]]; then
      err_fun 13 && continue
    fi
    break
  done

  newfile="n"
  ovpnauth="n"
  [[ $(dpkg --get-selections|grep -w "openvpn"|head -1) ]] && [[ -e /etc/openvpn/openvpn-status.log ]] && {

    while [[ ${newfile:-} != @(s|S|y|Y|n|N) ]]; do
      msg -ne "$(fun_trans "Crear Archivo") OpenVPN? [S/N]: "
      read -e -i S newfile
    done

    if [[ ${newfile} = @(s|S) ]]; then
      while [[ ${ovpnauth:-} != @(s|S|y|Y|n|N) ]]; do
        msg -ne "$(fun_trans "Autenticacion de usuario en el archivo")? [S/N]: "
        read -e -i S ovpnauth
      done
    fi
  }

  add_user "${nomeuser}" "${senhauser}" "${diasuser}" "${limiteuser}" "${newfile}" "${ovpnauth}"
  echo "${nomeuser}|${senhauser}" >> ${VPS_user}/passwd
  msg -ne " $(fun_trans "IP del Servidor"): " && msg -ama "    $(fun_ip)"
  msg -ne " $(fun_trans "Usuario"): " && msg -ama "            $nomeuser"
  msg -ne " $(fun_trans "Contraseña"): " && msg -ama "         $senhauser"
  msg -ne " $(fun_trans "Dias de Duracion"): " && msg -ama "   $diasuser"
  msg -ne " $(fun_trans "Limite de Conexion"): " && msg -ama " $limiteuser"
  msg -ne " $(fun_trans "Fecha de Expiracion"): " && msg -ama "$(date "+%F" -d " + $diasuser days")"
  [[ ! -z "$zip_ovpn" ]] && msg -ne " $(fun_trans "Archivo OVPN"): " && msg -ama "       $zip_ovpn"
  msg -bar
  print_center "$(msg -ama "►► Presione enter para continuar ◄◄")"
  read
}

#======CREAR USUARIO TEMPORAL======

mktmpuser(){
        name=""
        pass=""
        tmp=""
        while [[ -z $name ]]; do
                msg -ne " Nombre del usuario: "
                read name
                if [[ -z $name ]]; then
                        tput cuu1 && tput dl1
                        msg -ama " Escriva un nombre de usuario"
                        sleep 2
                        tput cuu1 && tput dl1
                        unset name
                        continue
                fi
        done

        if cat /etc/passwd |grep $name: |grep -vi [a-z]$name |grep -v [0-9]$name > /dev/null ; then
                tput cuu1 && tput dl1
                msg -verm2 " El usuario $name ya existe"
                sleep 2
                tput cuu1 && tput dl1
                return
        fi

        while [[ -z $pass ]]; do
                msg -ne " Contraseña: "
                read pass
                if [[ -z $pass ]]; then
                        tput cuu1 && tput dl1
                        msg -ama " Escriva una Contraseña"
                        sleep 2
                        tput cuu1 && tput dl1
                        unset pass
                        continue
                fi
        done

        while [[ -z $tmp ]]; do
                msg -ne " Duracion en minutos: "
                read tmp
                if [[ -z $tmp ]]; then
                        tput cuu1 && tput dl1
                        msg -ama " Escriva un tiempo de duracion"
                        sleep 2
                        tput cuu1 && tput dl1
                        unset tmp
                        continue
                fi
        done

        if [[ -z ${1:-} ]]; then
                msg -ne " Aplicar a conf Default [S/N]: "
                read def
                if [[ ! "$def" != @(s|S|y|Y) ]]; then
                        echo -e "usuario=$name
Contraseña=$pass
Tiempo=$tmp" > ${Default}
                fi
        fi

        useradd -M -s /bin/false -p $(openssl passwd -6 $pass) $name
        touch /tmp/$name

        timer=$(( $tmp * 60 ))
        echo "#!/bin/bash
sleep $timer
kill"' $(ps -u '"$name |awk '{print"' $tmp'"}') 1> /dev/null 2> /dev/null
userdel --force $name
rm -rf /tmp/$name
exit" > /tmp/$name

        chmod 777 /tmp/$name
        touch /tmp/cmd
        chmod 777 /tmp/cmd
        echo "nohup /tmp/$name & >/dev/null" > /tmp/cmd
        /tmp/cmd 2>/dev/null 1>/dev/null
        rm -rf /tmp/cmd

        title "USUARIO TEMPORAL CREADO"
        echo -e " $(msg -verm2 "IP:        ") $(msg -ama "$(fun_ip)")"
        echo -e " $(msg -verm2 "Usuario:   ") $(msg -ama "$name")"
        echo -e " $(msg -verm2 "Contraseña:") $(msg -ama "$pass")"
        echo -e " $(msg -verm2 "Duracion:  ") $(msg -ama "$tmp minutos")"
        msg -bar
        read foo
        return
}

userTMP(){
        tmp_f="${VPS_user}/userTMP" && [[ ! -d ${tmp_f} ]] && mkdir ${tmp_f}
        Default="${tmp_f}/Default"
        if [[ ! -e ${Default} ]]; then
                echo -e "usuario=VPS-SN
Contraseña=VPS-SN
Tiempo=15" > ${Default}
        fi

        name="$(cat ${Default}|grep "usuario"|cut -d "=" -f2)"
        pass="$(cat ${Default}|grep "Contraseña"|cut -d "=" -f2)"
        tmp="$(cat ${Default}|grep "Tiempo"|cut -d "=" -f2)"

        title "CONF DE USUARIO TEMPORAL"
        print_center_bar "${NC}Usuario Default"
        msg -bar3
        echo -e " $(msg -verm2 "IP:        ") $(msg -ama "$(fun_ip)")"
        echo -e " $(msg -verm2 "Usuario:   ") $(msg -ama "$name")"
        echo -e " $(msg -verm2 "Contraseña:") $(msg -ama "$pass")"
        echo -e " $(msg -verm2 "Duracion:  ") $(msg -ama "$tmp minutos")"
        msg -bar
        menu_func "APLICAR CONF DEFAULT" "CONF PERSONALIZADA"
        back
        opcion=$(selection_fun 2)
        case $opcion in
                1)mktmpuser "def";;
                2)unset name
                  unset pass
                  unset tmp
                  mktmpuser;;
                0)return;;
        esac
}

#=====REMOVER USUARIO=======================
rm_user(){
  #nome
  if userdel --force "$1" 2>/dev/null; then
    sed -i "/$1/d" ${VPS_user}/passwd 2>/dev/null
          print_center "$(msg -verd "[$(fun_trans "Removido")]")"
  else
          print_center "$(msg -verm "[$(fun_trans "No Removido")]")"
  fi
}

remove_user(){
        clear
        usuarios_ativos=('' $(mostrar_usuarios))
        msg -bar
        print_center_bar "$(msg -ama "$(fun_trans "REMOVER USUARIOS")")"
        msg -bar
        data_user
        back

        print_center "$(msg -ama "$(fun_trans "Escriba o Seleccione un Usuario")")"
        msg -bar
        selection=""
        while [[ -z ${selection} ]]; do
                msg -ne "$(fun_trans "Seleccione Una Opcion"): " && read selection
                tput cuu1 && tput dl1
        done
        [[ ${selection} = "0" ]] && return
        if [[ ! $(echo "${selection}" | egrep '[^0-9]') ]]; then
                usuario_del="${usuarios_ativos[$selection]}"
        else
                usuario_del="$selection"
        fi
        [[ -z $usuario_del ]] && {
                msg -verm "$(fun_trans "Error, Usuario Invalido")"
                msg -bar
                return 1
        }
        [[ ! $(echo ${usuarios_ativos[@]}|grep -w "$usuario_del") ]] && {
                msg -verm "$(fun_trans "Error, Usuario Invalido")"
                msg -bar
                return 1
        }

        print_center "$(msg -ama "$(fun_trans "Usuario Seleccionado"): $usuario_del")"
        pkill -u $usuario_del 2>/dev/null
        droplim=`droppids|grep -w "$usuario_del"|awk '{print $2}'` 
        kill -9 $droplim 2>/dev/null
        rm_user "$usuario_del"
        msg -bar
        sleep 3
}

#========RENOVAR USUARIOS==========

renew_user_fun(){
  #nome dias
  datexp=$(date "+%F" -d " + $2 days") && valid=$(date '+%C%y-%m-%d' -d " + $2 days")
  if chage -E $valid $1 2>/dev/null; then
          print_center "$(msg -ama "$(fun_trans "Usuario Renovado Con Exito")")"
  else
          print_center "$(msg -verm "$(fun_trans "Error, Usuario no Renovado")")"
  fi
}

renew_user(){
  clear
  usuarios_ativos=('' $(mostrar_usuarios))
  msg -bar
  print_center_bar "$(msg -ama "$(fun_trans "RENOVAR USUARIOS")")"
  msg -bar
  data_user
  back

  print_center "$(msg -ama "$(fun_trans "Escriba o seleccione un Usuario")")"
  msg -bar
  selection=""
  while [[ -z ${selection} ]]; do
    msg -ne "$(fun_trans " Seleccione una Opcion"): " && read selection
    tput cuu1 && tput dl1
  done

  [[ ${selection} = "0" ]] && return
  if [[ ! $(echo "${selection}" | egrep '[^0-9]') ]]; then
    useredit="${usuarios_ativos[$selection]}"
  else
    useredit="$selection"
  fi

  [[ -z $useredit ]] && {
    msg -verm "$(fun_trans "Error, Usuario Invalido")"
    msg -bar
    sleep 3
    return 1
  }

  [[ ! $(echo ${usuarios_ativos[@]}|grep -w "$useredit") ]] && {
    msg -verm "$(fun_trans "Error, Usuario Invalido")"
    msg -bar
    sleep 3
    return 1
  }

  while true; do
    msg -ne "$(fun_trans "Nuevo Tiempo de Duracion de"): $useredit"
    read -p ": " diasuser
    if [[ -z "$diasuser" ]]; then
      echo -e '\n\n\n'
      err_fun 7 && continue
    elif [[ "$diasuser" != +([0-9]) ]]; then
      echo -e '\n\n\n'
      err_fun 8 && continue
    elif [[ "$diasuser" -gt "360" ]]; then
      echo -e '\n\n\n'
      err_fun 9 && continue
    fi
    break
  done
  msg -bar
  renew_user_fun "${useredit}" "${diasuser}"
  msg -bar
  sleep 3
}

edit_user_fun(){
  datexp=$(date "+%F" -d " + $3 days") && valid=$(date '+%C%y-%m-%d' -d " + $3 days")
  clear
  msg -bar
  if usermod -p $(openssl passwd -6 $2) -e $valid -c $4,$2 $1 2>/dev/null; then
          print_center "$(msg -verd "Usuario Modificado Con Exito")"
  else
          print_center "$(msg -verm2 "Error, Usuario no Modificado")"
          msg -bar
          sleep 3
          return
  fi
  msg -bar
}

edit_user(){
  clear
  usuarios_ativos=('' $(mostrar_usuarios))
  msg -bar
  print_center_bar "$(msg -ama "$(fun_trans "EDITAR USUARIOS")")"
  msg -bar
  data_user
  back

  print_center "$(msg -ama "$(fun_trans "Escriba o seleccione un Usuario")")"
  msg -bar
  selection=""
  while [[ -z ${selection} ]]; do
    msg -ne "$(fun_trans " Seleccione una Opcion"): " && read selection
    tput cuu1; tput dl1
  done
  [[ ${selection} = "0" ]] && return
  if [[ ! $(echo "${selection}" | egrep '[^0-9]') ]]; then
    useredit="${usuarios_ativos[$selection]}"
  else
    useredit="$selection"
  fi
  [[ -z $useredit ]] && {
    msg -verm "$(fun_trans "Error, Usuario Invalido")"
    msg -bar
    return 1
  }
  [[ ! $(echo ${usuarios_ativos[@]}|grep -w "$useredit") ]] && {
    msg -verm "$(fun_trans "Error, Usuario Invalido")"
    msg -bar
    return 1
  }
  while true; do
    msg -ne "$(fun_trans "Usuario Seleccionado"): " && echo -e "$useredit"
    msg -ne "$(fun_trans "Nueva Contraseña de") $useredit"
    read -p ": " senhauser
    if [[ -z "$senhauser" ]]; then
      err_fun 4 && continue
    elif [[ "${#senhauser}" -lt "4" ]]; then
      err_fun 5 && continue
    elif [[ "${#senhauser}" -gt "12" ]]; then
      err_fun 6 && continue
    fi
    break
  done
  while true; do
    msg -ne "$(fun_trans "Dias de Duracion de"): $useredit"
    read -p ": " diasuser
    if [[ -z "$diasuser" ]]; then
      err_fun 7 && continue
    elif [[ "$diasuser" != +([0-9]) ]]; then
      err_fun 8 && continue
    elif [[ "$diasuser" -gt "360" ]]; then
      err_fun 9 && continue
    fi
    break
  done
  while true; do
    msg -ne "$(fun_trans "Nuevo Limite de Conexion de"): $useredit"
    read -p ": " limiteuser
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

  msg -ne " $(fun_trans "IP del Servidor"): " && msg -ama "    $(fun_ip)"
  msg -ne " $(fun_trans "Usuario"): " && msg -ama "            $useredit"
  msg -ne " $(fun_trans "Contraseña"): " && msg -ama "         $senhauser"
  msg -ne " $(fun_trans "Dias de Duracion"): " && msg -ama "   $diasuser"
  msg -ne " $(fun_trans "Limite de Conexion"): " && msg -ama " $limiteuser"
  msg -ne " $(fun_trans "Fecha de Expiracion"): " && msg -ama "$(date "+%F" -d " + $diasuser days")"
  msg -bar
  print_center "$(msg -ama "►► Presione enter para continuar ◄◄")"
  read
}

eliminar_all(){
  title "ELIMINAR TODOS LOS USUARIOS"
  msg -ne " [S/N]: "
  read opcion
  [[ "${opcion}" != @(S|s) ]] && return 1
  service dropbear stop &>/dev/null
  service sshd stop &>/dev/null
  service ssh stop &>/dev/null
  service stunnel4 stop &>/dev/null
  service squid stop &>/dev/null

  cat_users=$(cat /etc/passwd|grep 'home'|grep 'false'|grep -v 'syslog'|grep -v "hwid"|grep -v "token")

  for user in `echo "$cat_users"|awk -F ':' '{print $1}'`; do
    userpid=$(ps -u $user |awk {'print $1'})
    kill "$userpid" 2>/dev/null
    userdel --force $user 2>/dev/null
    user2=$(printf '%-15s' "$user")
    echo -e " $(msg -azu "USUARIO:") $(msg -ama "$user2")$(msg -verm2 "Eliminado")"
  done
  service sshd restart &>/dev/null
  service ssh restart &>/dev/null
  service dropbear start &>/dev/null
  service stunnel4 start &>/dev/null
  service squid restart &>/dev/null
  msg -bar
  print_center "$(msg -ama "USUARIOS ELIMINANDOS")"
  enter
  return 1
}
#===============MONITOR================
#===============MONITOR================
sshmonitor(){
  clear

  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
  echo -e "${Y}           📡 MONITOR DE USUARIOS SSH / VPN 📡${N}"
  echo -e "${R}────────────────────────── / / / ──────────────────────────${N}"

  # ENCABEZADO (MISMO FORMATO QUE LAS FILAS)
  printf " %-14s %-12s %-16s %-10s\n" \
  "USUARIO" "ESTADO" "CONEXIONES" "TIEMPO"

  echo -e "${R}────────────────────────── / / / ──────────────────────────${N}"

  # usuarios válidos
  cat_users=$(awk -F: '$3>=1000 && $7 ~ /false/ {print}' /etc/passwd)

  for i in $(echo "$cat_users" | awk -F: '{print $1}'); do

    user="$i"

    # ===== LIMITE =====
    s2ssh=$(echo "$cat_users" | grep -w "$i" | awk -F: '{print $5}' | cut -d',' -f1)
    [[ -z "$s2ssh" ]] && s2ssh=0

    # ===== SSH =====
    sshd=$(ps -u "$user" | grep sshd | wc -l)

    # ===== DROPBEAR =====
    if netstat -nltp | grep dropbear >/dev/null; then
      drop=$(ps aux | grep dropbear | grep "$user" | wc -l)
    else
      drop=0
    fi

    # ===== OPENVPN =====
    if [[ -e /etc/openvpn/openvpn-status.log ]]; then
      ovp=$(grep -E ",$user," /etc/openvpn/openvpn-status.log | wc -l)
    else
      ovp=0
    fi

    # ===== CONEXIONES =====
    cnx=$((sshd + drop))
    conex=$((cnx + ovp))

    # ===== TIEMPO =====
    if [[ $cnx -gt 0 ]]; then
      pid=$(ps -u "$user" | grep sshd | awk 'NR==1{print $1}')
      timerr=$(ps -o etime= -p "$pid" | sed 's/^ *//')
      [[ ${#timerr} -lt 8 ]] && timerr="00:$timerr"
    elif [[ $ovp -gt 0 ]]; then
      tmp2=$(date +%H:%M:%S)
      tmp1=$(grep -w "$user" /etc/openvpn/openvpn-status.log | awk '{print $4}' | head -1)
      [[ -z "$tmp1" ]] && tmp1="00:00:00" && tmp2="00:00:00"

      calc1=$(echo "${tmp1:0:2}*3600 + ${tmp1:3:2}*60 + ${tmp1:6:2}" | bc)
      calc2=$(echo "${tmp2:0:2}*3600 + ${tmp2:3:2}*60 + ${tmp2:6:2}" | bc)

      seg=$((calc2-calc1))
      hor=$((seg/3600))
      min=$(((seg%3600)/60))
      seg=$((seg%60))
      timerr=$(printf "%02d:%02d:%02d" $hor $min $seg)
    else
      timerr="00:00:00"
    fi

    # ===== FORMATO LIMPIO (SIN COLORES) =====
    userf=$(printf '%-14s' "$user")
    estado_txt=$(printf '%-12s' "$( [[ $conex -eq 0 ]] && echo OFFLINE || echo ONLINE )")
    conf=$(printf '%-14s' "$conex/$s2ssh")
    timef=$(printf '%-10s' "$timerr")

    # ===== COLOR DE ESTADO =====
    [[ $conex -eq 0 ]] && estado_color=$R || estado_color=$G

    # ===== IMPRESIÓN FINAL =====
    printf " ${Y}%-14s${N} ${estado_color}%-14s${N} ${G}%-14s${N} ${Y}%-10s${N}\n" \
    "$userf" "$estado_txt" "$conf" "$timef"
   echo -e "${R}─────────────────────────── / / / ──────────────────────────${N}"
   done
  echo -e "${Y}            ►► Presione ENTER para continuar ◄◄${N}"
  read
}

#===============FIN===============

detail_user(){
        clear
        usuarios_ativos=('' $(mostrar_usuarios))
        if [[ -z ${usuarios_ativos[@]} ]]; then
                msg -bar
                print_center "$(msg -verm2 "$(fun_trans "Ningun usuario registrado")")"
                msg -bar
                sleep 3
                return
        else
                msg -bar
                print_center_bar "$(msg -ama "$(fun_trans "DETALLES DEL LOS USUARIOS")")"
                msg -bar
        fi
        data_user
        msg -bar
        print_center "$(msg -ama "►► Presione enter para continuar ◄◄")"
        read
}

block_user(){
  clear
  usuarios_ativos=('' $(mostrar_usuarios))
  msg -bar
  print_center_bar "$(msg -ama "$(fun_trans "BLOQUEAR/DESBLOQUEAR USUARIOS")")"
  msg -bar
  data_user
  back

  print_center "$(msg -ama "$(fun_trans "Escriba o Seleccione Un Usuario")")"
  msg -bar
  selection=""
  while [[ ${selection} = "" ]]; do
    msg -ne "$(fun_trans "Seleccione"): " && read selection
    tput cuu1 && tput dl1
  done
  [[ ${selection} = "0" ]] && return
  if [[ ! $(echo "${selection}" | egrep '[^0-9]') ]]; then
    usuario_del="${usuarios_ativos[$selection]}"
  else
    usuario_del="$selection"
  fi
  [[ -z $usuario_del ]] && {
    msg -verm "$(fun_trans "Error, Usuario Invalido")"
    msg -bar
    return 1
  }
  [[ ! $(echo ${usuarios_ativos[@]}|grep -w "$usuario_del") ]] && {
    msg -verm "$(fun_trans "Error, Usuario Invalido")"
    msg -bar
    return 1
  }

  msg -nama "   $(fun_trans "Usuario"): $usuario_del >>>> "

  if [[ $(passwd --status $usuario_del|cut -d ' ' -f2) = "P" ]]; then
    pkill -u $usuario_del 2>/dev/null
    droplim=`droppids|grep -w "$usuario_del"|awk '{print $2}'` 
    kill -9 $droplim 2>/dev/null
    usermod -L $usuario_del 2>/dev/null
    sleep 2
    msg -verm2 "$(fun_trans "Bloqueado")"
  else
          usermod -U $usuario_del 2>/dev/null
          sleep 2
          msg -verd "$(fun_trans "Desbloqueado")"
  fi
  msg -bar
  sleep 3
}

rm_vencidos(){
        title "REMOVER USUARIOS VENCIDOS"
        print_center "$(msg -ama " Removera todo los usuarios ssh expirado")"
        msg -bar
        msg -ne " Continua [S/N]: "
        read opcion
        tput cuu1 && tput dl1
        [[ "$opcion" != @(s|S|y|Y) ]] && return

        expired="$(fun_trans "Expirado")"
        removido="$(fun_trans "Removido")"
        DataVPS=$(date +%s)

        while read user; do
                DataUser=$(chage -l "$user"|sed -n '4p'|awk -F ': ' '{print $2}')
                [[ "$DataUser" = @(never|nunca) ]] && continue
                DataSEC=$(date +%s --date="$DataUser")

                if [[ "$DataSEC" -lt "$DataVPS" ]]; then
                        pkill -u $user 2>/dev/null
                        droplim=`droppids|grep -w "$user"|awk '{print $2}'` 
                        kill -9 $droplim 2>/dev/null
                        userdel $user 2>/dev/null
                        print_center "$(msg -ama "$user $expired ($removido)")"
                        sleep 1
                fi
        done <<< "$(mostrar_usuarios)"
        enter
}

numero='^[0-9]+$'
limiter(){

        ltr(){
                clear
                msg -bar
                for i in `atq 2>/dev/null|awk '{print $1}'`; do
                        if [[ ! $(at -c $i 2>/dev/null|grep 'limitador.sh') = "" ]]; then
                                atrm $i 2>/dev/null
                                sed -i '/limitador.sh/d' /var/spool/cron/crontabs/root 2>/dev/null
                                print_center "$(msg -verd "limitador detenido")"
                                msg -bar
                                print_center "$(msg -ama "►► Presione enter para continuar ◄◄")"
                                read
                                return
                        fi
                done
    print_center_bar "$(msg -ama "CONF LIMITADOR")"
    msg -bar
    print_center "$(msg -ama "Bloquea usuarios cuando exeden")"
    print_center "$(msg -ama "el numero maximo conecciones")"
    msg -bar
    opcion=""
    while [[ -z $opcion ]]; do
      msg -nama " Ejecutar limitdor cada: "
      read opcion
      if [[ ! $opcion =~ $numero ]]; then
        tput cuu1 && tput dl1
        print_center "$(msg -verm2 " Solo se admiten nuemros")"
        sleep 2
        tput cuu1 && tput dl1
        unset opcion && continue
      elif [[ $opcion -le 0 ]]; then
        tput cuu1 && tput dl1
        print_center "$(msg -verm2 " tiempo minimo 1 minuto")"
        sleep 2
        tput cuu1 && tput dl1
        unset opcion && continue
      fi
      tput cuu1 && tput dl1
      echo -e "$(msg -nama " Ejecutar limitdor cada:") $(msg -verd "$opcion minutos")"
      echo "$opcion" > ${VPS_user}/limit
    done

    msg -bar
    print_center "$(msg -ama "Los usuarios bloqueados por el limitador")"
    print_center "$(msg -ama "seran desbloqueado automaticamente")"
    print_center "$(msg -ama "(ingresa 0 para desbloqueo manual)")"
    msg -bar

    opcion=""
    while [[ -z $opcion ]]; do
      msg -nama " Desbloquear user cada: "
      read opcion
      if [[ ! $opcion =~ $numero ]]; then
        tput cuu1 && tput dl1
        print_center "$(msg -verm2 " Solo se admiten nuemros")"
        sleep 2
        tput cuu1 && tput dl1
        unset opcion && continue
      fi
      tput cuu1 && tput dl1
      [[ $opcion -le 0 ]] && echo -e "$(msg -nama " Desbloqueo:") $(msg -verd "manual")" || echo -e "$(msg -nama " Desbloquear user cada:") $(msg -verd "$opcion minutos")"
      echo "$opcion" > ${VPS_user}/unlimit
    done
                nohup ${VPS_inst}/limitador.sh &>/dev/null &
    msg -bar
                print_center "$(msg -verd "limitador en ejecucion")"
                msg -bar
                print_center "$(msg -ama "►► Presione enter para continuar ◄◄")"
                read                
        }

        l_exp(){
                clear
            msg -bar
            l_cron=$(cat /var/spool/cron/crontabs/root 2>/dev/null|grep -w 'limitador.sh'|grep -w 'ssh')
            if [[ -z "$l_cron" ]]; then
                      echo '@daily /etc/VPS-SN/install/limitador.sh --ssh' >> /var/spool/cron/crontabs/root
                      print_center "$(msg -verd "limitador de expirados programado\nse ejecutara todos los dias a las 00hs\nsegun la hora programada en el servidor")"
                      enter
                      return
            else
                      sed -i '/limitador.sh --ssh/d' /var/spool/cron/crontabs/root 2>/dev/null
                      print_center "$(msg -verm2 "limitador de expirados detenido")"
                      enter
                      return   
            fi
        }

        log(){
                clear
                msg -bar
                print_center_bar "$(msg -ama "REGISTRO DEL LIMITADOR")"
                msg -bar
                [[ ! -e ${VPS_user}/limit.log ]] && touch ${VPS_user}/limit.log
                if [[ -z $(cat ${VPS_user}/limit.log) ]]; then
                        print_center "$(msg -ama "no ahy registro de limitador")"
                        msg -bar
                        sleep 2
                        return
                fi
                msg -teal "$(cat ${VPS_user}/limit.log)"
                msg -bar
                print_center "$(msg -ama "►► Presione enter para continuar o ◄◄")"
                print_center "$(msg -ama "►► 0 para limpiar registro ◄◄")"
                read opcion
                [[ $opcion = "0" ]] && echo "" > ${VPS_user}/limit.log
        }

        [[ $(cat /var/spool/cron/crontabs/root 2>/dev/null|grep -w 'limitador.sh'|grep -w 'ssh') ]] && lim_e=$(msg -verd "[ON]") || lim_e=$(msg -verm2 "[OFF]")

        clear
        msg -bar
        print_center_bar "$(msg -ama "LIMITADOR DE CUENTAS")"
        msg -bar
        menu_func "LIMTADOR DE CONECCIONES" "LIMITADOR DE EXPIRADOS $lim_e" "LIMITADOR DE DATOS $(msg -verm2 "(no diponible)")" "LOG DEL LIMITADOR"
        back
        msg -ne " opcion: "
        read opcion
        case $opcion in
                1)ltr;;
                2)l_exp;;
                3);;
                4)log;;
                0)return;;
        esac
}

invalid_option() {
  clear
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
  echo -e "${B}                   OPCIÓN INVÁLIDA${N}"
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
  sleep 2
}

backup(){
  # Función para respaldar usuarios (implementación básica)
  title "BACKUP USUARIOS"
  print_center "$(msg -ama "Creando respaldo de usuarios...")"
  cp ${VPS_user}/passwd ${VPS_user}/B-VPSuser/backup_$(date +%Y%m%d_%H%M%S).txt 2>/dev/null || print_center "$(msg -verm2 "Error al crear respaldo")"
  print_center "$(msg -verd "Respaldo creado")"
  enter
}

ULK_ALF(){
  # Función para desactivar PASS alfanumérico (para Vultr, implementación básica)
  title "DESACTIVAR PASS ALFANUMERICO"
  print_center "$(msg -ama "Desactivando PASS alfanumérico para Vultr...")"
  # Aquí iría la lógica específica, por ejemplo, modificar configuraciones
  print_center "$(msg -verd "Completado (simulado)")"
  enter
}

USER_MODE(){
        title "SELECCIONE EL MODO QUE USARA POR DEFECTO"
        menu_func "HWID" "TOKEN"
        back
        opcion=$(selection_fun 2)
        case $opcion in
                1) echo "userHWID" > ${VPS_user}/userMODE
                   clear
                   msg -bar
                   print_center "$(msg -verd "MODO HWID ACTIVA")"
                   enter;;
                2) echo "userTOKEN" > ${VPS_user}/userMODE
                   clear
                   msg -bar
                   print_center "$(msg -verd "MODO TOKEN ACTIVA")"
                   enter;;
                0)return 1;;
        esac
}

while :
do
        lim=$(msg -verm2 "[OFF]")
        for i in `atq 2>/dev/null|awk '{print $1}'`; do
                if [[ ! $(at -c $i 2>/dev/null|grep 'limitador.sh') = "" ]]; then
                        lim=$(msg -verd "[ON]")
                fi
        done

          title "ADMINISTRACION DE USUARIOS SSH"

        msg -bar3
        menu_func "NUEVO USUARIO SSH ✏️ " \
"CREAR USUARIO TEMPORAL✏️." \
"$(msg -verm2 "REMOVER USUARIO") 🗑 " \
"$(msg -verd "RENOVAR USUARIO") ♻️" \
"EDITAR USUARIO 📝" \
"BLOQ/DESBLOQ USUARIO 🔒\n$(msg -bar3)" \
"$(msg -verd "DETALLES DE TODOS USUARIOS") 🔎" \
"MONITOR DE USUARIOS CONECTADOS" \
"🔒 $(msg -ama "LIMITADOR-DE-CUENTAS") 🔒 $lim\n$(msg -bar3)" \
"ELIMINAR USUARIOS VENCIDOS" \
"⚠️ $(msg -verm2 "ELIMINAR TODOS LOS USUARIOS") ⚠️\n$(msg -bar3)" \
"BACKUP USUARIOS" \
"${G}DESACTIVAR PASS ALFANUMERICO ${B}(VULTR)${N}" \
"CAMBIAR A MODO HWID/TOKEN"

        back
        selection=$(selection_fun 14)
        case ${selection} in
                0)break;;
                1)new_user;;
                2)userTMP;;
                3)remove_user;;
                4)renew_user;;
                5)edit_user;;
                6)block_user;;
                7)detail_user;;
                8)sshmonitor;;
                9)limiter;;
                10)rm_vencidos;;
                11)eliminar_all;;
                12)backup;;
                13)ULK_ALF;;
                14)USER_MODE && break;;
        esac
done
