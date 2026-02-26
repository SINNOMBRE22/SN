#!/bin/bash

# ==================================================
#  SLOWDNS INDEPENDIENTE
#  Resolución automática de rutas
# ==================================================

[[ $EUID -ne 0 ]] && echo "Ejecuta como root" && exit 1

BASE_DIR="/etc/slowdns"
ADM_slow="${BASE_DIR}"
ADM_inst="${BASE_DIR}"

mkdir -p ${ADM_slow}

# ========= COLORES =========
verde="\033[1;32m"
rojo="\033[1;31m"
amarillo="\033[1;33m"
azul="\033[1;34m"
reset="\033[0m"

msg() {
    case $1 in
        -bar) echo -e "${azul}══════════════════════════════${reset}" ;;
        -bar3) echo -e "${azul}──────────────────────────────${reset}" ;;
        -verd) echo -e "${verde}$2${reset}" ;;
        -verm2) echo -e "${rojo}$2${reset}" ;;
        -ama) echo -e "${amarillo}$2${reset}" ;;
        -azu) echo -e "${azul}$2${reset}" ;;
        -nama) echo -ne "${amarillo}$2${reset}" ;;
    esac
}

title() {
    clear
    msg -bar
    echo -e "${amarillo}$1${reset}"
    msg -bar
}

print_center() { msg $1 "$2"; }

enter() { echo; read -p "Presiona ENTER para continuar..."; }

selection_fun() { read -p "Seleccione una opción: " opt; echo $opt; }

menu_func() {
    echo -e "\n[1] $1"
    echo -e "[2] $2"
    echo -e "[3] $3"
    echo -e "[4] $4"
    echo -e "[0] Salir"
}

back() { echo; }

# ==================================================

info(){
    clear
    nodata(){
        msg -bar
        print_center -ama "SIN INFORMACION SLOWDNS!!!"
        enter
    }

    [[ ! -e ${ADM_slow}/domain_ns ]] && nodata && return
    [[ ! -e ${ADM_slow}/server.pub ]] && nodata && return

    msg -bar
    print_center -ama "DATOS DE SU CONECCION SLOWDNS"
    msg -bar
    msg -ama "Su NS (Nameserver): $(cat ${ADM_slow}/domain_ns)"
    msg -bar3
    msg -ama "Su Llave: $(cat ${ADM_slow}/server.pub)"
    enter
}

drop_port(){
    portasVAR=$(lsof -V -i tcp -P -n | grep -v "ESTABLISHED" |grep -v "COMMAND" | grep "LISTEN")
    unset DPB
    while read port; do
        reQ=$(echo ${port}|awk '{print $1}')
        Port=$(echo ${port} | awk '{print $9}' | awk -F ":" '{print $2}')
        case ${reQ} in
            sshd|dropbear|stunnel4|stunnel|python|python3) DPB+=" $reQ:$Port";;
        esac
    done <<< "${portasVAR}"
}

ini_slow(){
    title "INSTALADOR SLOWDNS"

    drop_port
    n=1
    for i in $DPB; do
        proto=$(echo $i|awk -F ":" '{print $1}')
        port=$(echo $i|awk -F ":" '{print $2}')
        echo -e " $(msg -verd "[$n]") $(msg -ama "$proto") $(msg -azu "$port")"
        drop[$n]=$port
        num_opc="$n"
        let n++
    done

    msg -bar
    opc=$(selection_fun)
    echo "${drop[$opc]}" > ${ADM_slow}/puerto
    PORT=$(cat ${ADM_slow}/puerto)

    unset NS
    while [[ -z $NS ]]; do
        msg -nama "Tu dominio NS: "
        read NS
    done

    echo "$NS" > ${ADM_slow}/domain_ns

    if [[ ! -e ${ADM_inst}/dns-server ]]; then
        msg -nama "Descargando binario..."
        if wget -O ${ADM_inst}/dns-server https://github.com/rudi9999/ADMRufu/raw/main/Utils/SlowDNS/dns-server &>/dev/null ; then
            chmod +x ${ADM_inst}/dns-server
            msg -verd " OK"
        else
            msg -verm2 " FAIL"
            enter
            return
        fi
    fi

    rm -f ${ADM_slow}/server.key ${ADM_slow}/server.pub
    ${ADM_inst}/dns-server -gen-key \
    -privkey-file ${ADM_slow}/server.key \
    -pubkey-file ${ADM_slow}/server.pub &>/dev/null

    msg -bar
    msg -nama "Iniciando SlowDNS..."

    iptables -I INPUT -p udp --dport 5300 -j ACCEPT
    iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300

    if screen -dmS slowdns ${ADM_inst}/dns-server -udp :5300 \
    -privkey-file ${ADM_slow}/server.key \
    $NS 127.0.0.1:$PORT ; then
        msg -verd " OK"
    else
        msg -verm2 " FAIL"
    fi

    enter
}

reset_slow(){
    clear
    msg -bar
    msg -nama "Reiniciando SlowDNS..."

    screen -ls | grep slowdns | cut -d. -f1 | awk '{print $1}' | xargs kill 2>/dev/null

    NS=$(cat ${ADM_slow}/domain_ns)
    PORT=$(cat ${ADM_slow}/puerto)

    if screen -dmS slowdns ${ADM_inst}/dns-server -udp :5300 \
    -privkey-file ${ADM_slow}/server.key \
    $NS 127.0.0.1:$PORT ; then
        msg -verd " OK"
    else
        msg -verm2 " FAIL"
    fi

    enter
}

stop_slow(){
    clear
    msg -bar
    msg -nama "Deteniendo SlowDNS..."

    if screen -ls | grep slowdns | cut -d. -f1 | awk '{print $1}' | xargs kill 2>/dev/null ; then
        msg -verd " OK"
    else
        msg -verm2 " FAIL"
    fi

    enter
}

# =================== MENU ===================

while :
do
    clear
    msg -bar
    print_center -ama "INSTALADOR SLOWDNS"
    msg -bar

    menu_func "Ver Informacion" "Iniciar SlowDNS" "Reiniciar SlowDNS" "Parar SlowDNS"
    opcion=$(selection_fun)

    case $opcion in
        1) info ;;
        2) ini_slow ;;
        3) reset_slow ;;
        4) stop_slow ;;
        0) break ;;
    esac
done

exit 0
