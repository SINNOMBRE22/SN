#!/bin/bash

# Script optimizado para V2Ray v5.0+ y Xray
# Basado en el instalador multi-plataforma v5

# Argumentos del CLI
PROXY=''
HELP=''
FORCE=''
CHECK=''
REMOVE=''
VERSION=''
VSRC_ROOT='/tmp/v2ray'
EXTRACT_ONLY=''
LOCAL=''
LOCAL_INSTALL=''
ERROR_IF_UPTODATE=''

CUR_VER=""
NEW_VER=""
ZIPFILE="/tmp/v2ray/v2ray.zip"
V2RAY_RUNNING=0

CMD_INSTALL=""
CMD_UPDATE=""
SOFTWARE_UPDATED=0
KEY="V2Ray"
KEY_LOWER="v2ray"
REPOS="v2fly/v2ray-core"

SYSTEMCTL_CMD=$(command -v systemctl 2>/dev/null)

####### Colores ########
RED="31m"
GREEN="32m"
YELLOW="33m"
BLUE="36m"

xray_set(){
    KEY="Xray"
    KEY_LOWER="xray"
    REPOS="XTLS/Xray-core"
    VSRC_ROOT='/tmp/xray'
    ZIPFILE="/tmp/xray/xray.zip"
}

while [[ $# > 0 ]]; do
    case "$1" in
        -p|--proxy) PROXY="-x ${2}"; shift ;;
        -h|--help) HELP="1" ;;
        -f|--force) FORCE="1" ;;
        -c|--check) CHECK="1" ;;
        -x|--xray) xray_set ;;
        --remove) REMOVE="1" ;;
        --version) VERSION="$2"; shift ;;
        --extractonly) EXTRACT_ONLY="1" ;;
        -l|--local) LOCAL="$2"; LOCAL_INSTALL="1"; shift ;;
        *) ;;
    esac
    shift
done

colorEcho(){
    echo -e "\033[${1}${@:2}\033[0m" 1>& 2
}

archAffix(){
    case "$(uname -m)" in
      'i386' | 'i686') MACHINE='32' ;;
      'amd64' | 'x86_64') MACHINE='64' ;;
      'armv8' | 'aarch64') MACHINE='arm64-v8a' ;;
      'armv7' | 'armv7l') MACHINE='arm32-v7a' ;;
      *) echo "error: Arquitectura no soportada."; exit 1 ;;
    esac
    return 0
}

zipRoot() {
    unzip -lqq "$1" | awk 'NR == 1 {print $4}' | cut -d/ -f1
}

downloadV2Ray(){
    rm -rf /tmp/$KEY_LOWER
    mkdir -p /tmp/$KEY_LOWER
    local PACK_NAME=$KEY_LOWER
    [[ $KEY == "Xray" ]] && PACK_NAME=$KEY
    DOWNLOAD_LINK="https://github.com/$REPOS/releases/download/${NEW_VER}/${PACK_NAME}-linux-${MACHINE}.zip"
    colorEcho ${BLUE} "Descargando $KEY $NEW_VER: ${DOWNLOAD_LINK}"
    curl ${PROXY} -L -H "Cache-Control: no-cache" -o ${ZIPFILE} ${DOWNLOAD_LINK}
    return $?
}

getPMT(){
    if [[ -n `command -v apt-get` ]];then
        CMD_INSTALL="apt-get -y -qq install"; CMD_UPDATE="apt-get -qq update"
    elif [[ -n `command -v yum` ]]; then
        CMD_INSTALL="yum -y -q install"; CMD_UPDATE="yum -q makecache"
    else
        return 1
    fi
    return 0
}

installSoftware(){
    COMPONENT=$1
    if [[ -n `command -v $COMPONENT` ]]; then return 0; fi
    getPMT || return 1
    [[ $SOFTWARE_UPDATED -eq 0 ]] && $CMD_UPDATE && SOFTWARE_UPDATED=1
    $CMD_INSTALL $COMPONENT
}

normalizeVersion() {
    if [ -n "$1" ]; then [[ "$1" == v* ]] && echo "$1" || echo "v$1"; fi
}

getVersion(){
    if [[ -n "$VERSION" ]]; then
        NEW_VER="$(normalizeVersion "$VERSION")"
        return 4
    else
        # V5+ usa 'v2ray version'
        VER="$(/usr/bin/$KEY_LOWER/$KEY_LOWER version 2>/dev/null | head -n 1 | cut -d " " -f2)"
        CUR_VER="$(normalizeVersion "$VER")"
        TAG_URL="https://api.github.com/repos/$REPOS/releases/latest"
        NEW_VER="$(normalizeVersion "$(curl ${PROXY} -s "${TAG_URL}" | grep 'tag_name' | cut -d\" -f4)")"

        if [[ -z "$NEW_VER" ]]; then return 3; fi
        [[ -z "$VER" ]] && return 2
        [[ "$NEW_VER" != "$CUR_VER" ]] && return 1
        return 0
    fi
}

installV2Ray(){
    mkdir -p /etc/$KEY_LOWER /var/log/$KEY_LOWER
    # En V5+ solo extraemos el binario principal y los archivos .dat
    unzip -oj "$1" "$2${KEY_LOWER}" "$2geoip.dat" "$2geosite.dat" -d /usr/bin/$KEY_LOWER
    chmod +x /usr/bin/$KEY_LOWER/$KEY_LOWER

    if [ ! -f /etc/$KEY_LOWER/config.json ]; then
        local UUID=$(cat /proc/sys/kernel/random/uuid)
        cat > /etc/$KEY_LOWER/config.json <<EOF
{
  "inbounds": [{
    "port": 443,
    "protocol": "vmess",
    "settings": {
      "clients": [{ "id": "$UUID" }]
    }
  }],
  "outbounds": [{ "protocol": "freedom" }]
}
EOF
        colorEcho ${BLUE} "Configuración creada: /etc/$KEY_LOWER/config.json"
        colorEcho ${GREEN} "PORT: 443 | UUID: $UUID"
    fi
}

installInitScript(){
    cat > /etc/systemd/system/$KEY_LOWER.service <<EOF
[Unit]
Description=${KEY} Service
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/bin/$KEY_LOWER/$KEY_LOWER run -config /etc/$KEY_LOWER/config.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable $KEY_LOWER
}

remove(){
    ${SYSTEMCTL_CMD} stop $KEY_LOWER 2>/dev/null
    ${SYSTEMCTL_CMD} disable $KEY_LOWER 2>/dev/null
    rm -rf "/usr/bin/$KEY_LOWER" "/etc/systemd/system/$KEY_LOWER.service"
    colorEcho ${GREEN} "$KEY eliminado correctamente."
}

main(){
    [[ "$HELP" == "1" ]] && echo "Uso: ./go.sh [-x (Xray)] [--remove] [--version v5.x.x]" && return
    [[ "$REMOVE" == "1" ]] && remove && return

    archAffix
    installSoftware "curl" || return 1
    installSoftware "unzip" || return 1

    getVersion
    RET=$?
    if [[ $RET -eq 0 && "$FORCE" != "1" ]]; then
        colorEcho ${GREEN} "Ya tienes la última versión: $CUR_VER"
        return
    fi

    downloadV2Ray || return 1
    local ZIPROOT="$(zipRoot "${ZIPFILE}")"

    [[ $(pgrep $KEY_LOWER) ]] && V2RAY_RUNNING=1 && ${SYSTEMCTL_CMD} stop $KEY_LOWER

    installV2Ray "${ZIPFILE}" "${ZIPROOT}"
    installInitScript

    [[ $V2RAY_RUNNING -eq 1 ]] && ${SYSTEMCTL_CMD} start $KEY_LOWER
    colorEcho ${GREEN} "$KEY $NEW_VER instalado con éxito."
}

main
