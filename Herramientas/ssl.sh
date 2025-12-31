#!/bin/bash

# =========================================================
# Gestión de Certificados SSL - SinNombre
# =========================================================

R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
B='\033[0;34m'
C='\033[0;36m'
W='\033[1;37m'
N='\033[0m'

# ===== RUTAS BASE SN =====
VPS_src="/etc/SN"
VPS_crt="/etc/SN/cert"
VPS_tmp="/tmp"

# ===== VALIDACIONES =====
numero='^[0-9]+$'
tx_num='^[a-zA-Z0-9_]+$'

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

# ===== INPUT =====
in_opcion() {
  read -p " $1: " opcion
}

#====FUNCIONES==========

cert_install(){
    #apt install socat netcat -y
    if [[ ! -e $HOME/.acme.sh/acme.sh ]];then
            msg -bar3
            msg -ama " Instalando script acme.sh"
            curl -s "https://get.acme.sh" | sh &>/dev/null
    fi
    if [[ ! -z "${mail}" ]]; then
            title "LOGEANDO EN Zerossl"
            sleep 3
            $HOME/.acme.sh/acme.sh --register-account  -m ${mail} --server zerossl
            $HOME/.acme.sh/acme.sh --set-default-ca --server zerossl
            enter
    else
            title "APLICANDO SERVIDOR letsencrypt"
            sleep 3
            $HOME/.acme.sh/acme.sh --set-default-ca --server letsencrypt
            enter
    fi
    title "GENERANDO CERTIFICADO SSL"
    sleep 3
    if "$HOME"/.acme.sh/acme.sh --issue -d "${domain}" --standalone -k ec-256 --force; then
            "$HOME"/.acme.sh/acme.sh --installcert -d "${domain}" --fullchainpath ${VPS_crt}/${domain}.crt --keypath ${VPS_crt}/${domain}.key --ecc --force &>/dev/null
            rm -rf $HOME/.acme.sh/${domain}_ecc
            msg -bar
            print_center -verd "Certificado SSL se genero con éxito"
            enter
            return 1
    else
            rm -rf "$HOME/.acme.sh/${domain}_ecc"
            msg -bar
            print_center -verm2 "Error al generar el certificado SSL"
            msg -bar
            msg -ama " verifique los posibles error"
            msg -ama " e intente de nuevo"
            enter
            return 1
    fi
 }

ext_cert(){
        unset cert
        declare -A cert
        title "INTALADOR DE CERTIFICADO EXTERNO"
        print_center -azu "Requiere tener a mano su certificado ssl"
        print_center -azu "junto a su correspondiente clave privada"
        msg -bar
        msg -ne " Continuar...[S/N]: "
        read opcion
        [[ $opcion != @(S|s|Y|y) ]] && return 1


        title "INGRESE EL CONTENIDO DE SU CERTIFICADO SSL"
        msg -ama ' a continuacion se abrira el editor de texto nano 
 ingrese el contenido de su certificado
 guardar precionando "CTRL+x"
 luego "S o Y" segun el idioma
 y por ultimo "enter"'
         msg -bar
         msg -ne " Continuar...[S/N]: "
        read opcion
        [[ $opcion != @(S|s|Y|y) ]] && return 1
        rm -rf ${VPS_tmp}/tmp.crt
        clear
        nano ${VPS_tmp}/tmp.crt

        title "INGRESE EL CONTENIDO DE CLAVE PRIVADA"
        msg -ama ' a continuacion se abrira el editor de texto nano 
 ingrese el contenido de su clave privada.
 guardar precionando "CTRL+x"
 luego "S o Y" segun el idioma
 y por ultimo "enter"'
         msg -bar
         msg -ne " Continuar...[S/N]: "
        read opcion
        [[ $opcion != @(S|s|Y|y) ]] && return 1
        ${VPS_tmp}/tmp.key
        clear
        nano ${VPS_tmp}/tmp.key

        if openssl x509 -in ${VPS_tmp}/tmp.crt -text -noout &>/dev/null ; then
                DNS=$(openssl x509 -in ${VPS_tmp}/tmp.crt -text -noout | grep 'DNS:'|sed 's/, /\n/g'|sed 's/DNS:\| //g')
                rm -rf ${VPS_crt}/*
                if [[ $(echo "$DNS"|wc -l) -gt "1" ]]; then
                        DNS="multi-domain"
                fi
                mv ${VPS_tmp}/tmp.crt ${VPS_crt}/$DNS.crt
                mv ${VPS_tmp}/tmp.key ${VPS_crt}/$DNS.key

                title "INSTALACION COMPLETA"
                echo -e "$(msg -verm2 "Domi: ")$(msg -ama "$DNS")"
                echo -e "$(msg -verm2 "Emit: ")$(msg -ama "$(openssl x509 -noout -in ${VPS_crt}/$DNS.crt -startdate|sed 's/notBefore=//g')")"
                echo -e "$(msg -verm2 "Expi: ")$(msg -ama "$(openssl x509 -noout -in ${VPS_crt}/$DNS.crt -enddate|sed 's/notAfter=//g')")"
                echo -e "$(msg -verm2 "Cert: ")$(msg -ama "$(openssl x509 -noout -in ${VPS_crt}/$DNS.crt -issuer|sed 's/issuer=//g'|sed 's/ = /=/g'|sed 's/, /\n      /g')")"
                msg -bar
                echo "$DNS" > ${VPS_src}/dominio.txt
                read foo
        else
                rm -rf ${VPS_tmp}/tmp.crt
                rm -rf ${VPS_tmp}/tmp.key
                clear
                msg -bar
                print_center -verm2 "ERROR DE DATOS"
                msg -bar
                msg -ama " Los datos ingresados no son validos.\n por favor verifique.\n e intente de nuevo!!"
                msg -bar
                read foo
        fi
        return 1
}

stop_port(){
        msg -bar3
        msg -ama " Comprovando puertos..."
        ports=('80' '443')

        for i in ${ports[@]}; do
                if [[ 0 -ne $(lsof -i:$i | grep -i -c "listen") ]]; then
                        msg -bar3
                        echo -ne "$(msg -ama " Liberando puerto: $i")"
                        lsof -i:$i | awk '{print $2}' | grep -v "PID" | xargs kill -9
                        sleep 2s
                        if [[ 0 -ne $(lsof -i:$i | grep -i -c "listen") ]];then
                                tput cuu1 && tput dl1
                                print_center -verm2 "ERROR AL LIBERAR PURTO $i"
                                msg -bar3
                                msg -ama " Puerto $i en uso."
                                msg -ama " auto-liberacion fallida"
                                msg -ama " detenga el puerto $i manualmente"
                                msg -ama " e intentar nuevamente..."
                                msg -bar
                                read foo
                                return 1                        
                        fi
                fi
        done
 }

ger_cert(){
        clear
        case $1 in
                1)title "Generador De Certificado Let's Encrypt";;
                2)title "Generador De Certificado Zerossl";;
        esac
        print_center -ama "Requiere ingresar un dominio."
        print_center -ama "el mismo solo deve resolver DNS, y apuntar"
        print_center -ama "a la direccion ip de este servidor."
        msg -bar3
        print_center -ama "Temporalmente requiere tener"
        print_center -ama "los puertos 80 y 443 libres."
        if [[ $1 = 2 ]]; then
                msg -bar3
                print_center -ama "Requiere tener una cuenta Zerossl."
        fi
        msg -bar
         msg -ne " Continuar [S/N]: "
        read opcion
        [[ $opcion != @(s|S|y|Y) ]] && return 1

        if [[ $1 = 2 ]]; then
     while [[ -z $mail ]]; do
             clear
                msg -bar
                print_center -ama "ingresa tu correo usado en zerossl"
                msg -bar3
                msg -ne " >>> "
                read mail
         done
        fi

        if [[ -e ${VPS_src}/dominio.txt ]]; then
                domain=$(cat ${VPS_src}/dominio.txt)
                [[ $domain = "multi-domain" ]] && unset domain
                if [[ ! -z $domain ]]; then
                        clear
                        msg -bar
                        print_center -azu "Dominio asociado a esta ip"
                        msg -bar3
                        echo -e "$(msg -verm2 " >>> ") $(msg -ama "$domain")"
                        msg -ne "Continuar, usando este dominio? [S/N]: "
                        read opcion
                        tput cuu1 && tput dl1
                        [[ $opcion != @(S|s|Y|y) ]] && unset domain
                fi
        fi

        while [[ -z $domain ]]; do
                clear
                msg -bar
                print_center -ama "ingresa tu dominio"
                msg -bar3
                msg -ne " >>> "
                read domain
        done
        msg -bar3
        msg -ama " Comprovando direccion IP ..."
        local_ip=$(wget -qO- ipv4.icanhazip.com)
    domain_ip=$(ping "${domain}" -c 1 | sed '1{s/[^(]*(//;s/).*//;q}')
    sleep 3
    [[ -z "${domain_ip}" ]] && domain_ip="ip no encontrada"
    if [[ $(echo "${local_ip}" | tr '.' '+' | bc) -ne $(echo "${domain_ip}" | tr '.' '+' | bc) ]]; then
            clear
            msg -bar
            print_center -verm2 "ERROR DE DIRECCION IP"
            msg -bar
            msg -ama " La direccion ip de su dominio\n no coincide con la de su servidor."
            msg -bar3
            echo -e " $(msg -azu "IP dominio:  ")$(msg -verm2 "${domain_ip}")"
            echo -e " $(msg -azu "IP servidor: ")$(msg -verm2 "${local_ip}")"
            msg -bar3
            msg -ama " Verifique su dominio, e intente de nuevo."
            msg -bar
            read foo
            return 1
    fi


    stop_port
    cert_install
    echo "$domain" > ${VPS_src}/dominio.txt
    return 1
}

del_cert() {
    title "ELIMINAR CERTIFICADO SSL"
    if [[ -d ${VPS_crt} && $(ls ${VPS_crt}/*.crt 2>/dev/null | wc -l) -gt 0 ]]; then
        msg -bar
        msg -ama "Certificados encontrados:"
        ls ${VPS_crt}/*.crt | xargs basename -a
        msg -bar
        msg -ne "Eliminar todos los certificados? [S/N]: "
        read opcion
        if [[ $opcion = @(S|s|Y|y) ]]; then
            rm -rf ${VPS_crt}/*
            rm -f ${VPS_src}/dominio.txt
            msg -bar
            print_center -verd "Certificados eliminados"
        else
            return 1
        fi
    else
        msg -bar
        print_center -verm2 "No hay certificados para eliminar"
    fi
    enter
    return 1
}

#======MENU======
menu_cert(){
title "SUB-DOMINIO Y CERTIFICADO SSL"
menu_func "GENERAR CERT SSL (Let's Encrypt)" "GENERAR CERT SSL (Zerossl)" "INGRESAR CERT SSL EXTERNO" "ELIMINAR CERTIFICADO SSL"
back
in_opcion "Opcion"

case $opcion in
        1)ger_cert 1;;
        2)ger_cert 2;;
        3)ext_cert;;
        4)del_cert;;
        0)return 1;;
esac
}

menu_cert
