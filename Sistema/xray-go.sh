#!/usr/bin/env bash
set -e

# =========================================
# XRAY GO INSTALLER - FIXED VERSION
# Inspired by ADMRufu go.sh
# =========================================

XRAY_REPO="XTLS/Xray-core"
INSTALL_BIN="/usr/local/bin/xray"
XRAY_DIR="/etc/xray"
SERVICE="/etc/systemd/system/xray.service"
TMP="/tmp/xray-go"

RED="\033[1;31m"; GREEN="\033[1;32m"; YELLOW="\033[1;33m"; NC="\033[0m"
log(){ echo -e "${GREEN}[XRAY]${NC} $1"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $1"; }

[[ $EUID -ne 0 ]] && { echo "Run as root"; exit 1; }

# =========================================
# Detectar arquitectura
# =========================================
arch() {
    case "$(uname -m)" in
        x86_64) echo "64" ;;
        i686|i386) echo "32" ;;
        aarch64|arm64) echo "arm64-v8a" ;;
        armv7l) echo "arm32-v7a" ;;
        *) echo "unsupported"; exit 1 ;;
    esac
}

# =========================================
# Dependencias
# =========================================
deps() {
    if command -v apt >/dev/null; then
        apt update -y >/dev/null 2>&1
        apt install -y curl unzip uuid-runtime >/dev/null 2>&1
    elif command -v yum >/dev/null; then
        yum install -y curl unzip util-linux >/dev/null 2>&1
    else
        echo "No package manager"; exit 1
    fi
}

# =========================================
# Obtener última versión
# =========================================
latest() {
    curl -s https://api.github.com/repos/$XRAY_REPO/releases/latest |
        grep tag_name | cut -d '"' -f4
}

# =========================================
# Descargar XRAY
# =========================================
download() {
    mkdir -p "$TMP"
    cd "$TMP"
    VER=$(latest)
    FILE="Xray-linux-$(arch).zip"
    URL="https://github.com/$XRAY_REPO/releases/download/$VER/$FILE"

    log "Descargando Xray $VER"
    curl -L -o "$FILE" "$URL"
    unzip -qo "$FILE"
}

# =========================================
# Backup binario anterior
# =========================================
backup() {
    if [[ -f $INSTALL_BIN ]]; then
        cp "$INSTALL_BIN" "$INSTALL_BIN.bak.$(date +%s)"
        warn "Backup creado"
    fi
}

# =========================================
# Instalar archivos
# =========================================
install_files() {
    backup
    install -m 755 xray "$INSTALL_BIN"
    mkdir -p "$XRAY_DIR"
    install -m 644 geoip.dat geosite.dat "$XRAY_DIR/"
}

# =========================================
# Crear configuración automática
# =========================================
make_config() {
    if [[ -f "$XRAY_DIR/config.json" ]]; then
        warn "config.json ya existe, no se recrea"
        return
    fi

    UUID=$(uuidgen)
    PORT=$((RANDOM%20000+20000))

cat > "$XRAY_DIR/config.json" <<EOF
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "warning"
  },
  "inbounds": [{
    "port": $PORT,
    "protocol": "vmess",
    "settings": {
      "clients": [{
        "id": "$UUID",
        "alterId": 0
      }]
    }
  }],
  "outbounds": [{
    "protocol": "freedom"
  }]
}
EOF

    log "Config creado"
    log "Puerto: $PORT"
    log "UUID: $UUID"
}

# =========================================
# Servicio systemd (FIX)
# =========================================
service() {
    if [[ -f $SERVICE ]]; then
        warn "Servicio ya existe"
        return
    fi

cat > "$SERVICE" <<EOF
[Unit]
Description=Xray Service
After=network.target

[Service]
ExecStart=$INSTALL_BIN run -config $XRAY_DIR/config.json
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reexec
    systemctl daemon-reload
    systemctl enable xray
}

# =========================================
# MAIN
# =========================================
deps
download
install_files
make_config
service

systemctl restart xray
log "XRAY INSTALADO Y EJECUTÁNDOSE"
