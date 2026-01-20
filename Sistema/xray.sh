#!/bin/bash

BEIJING_UPDATE_TIME=3
BEGIN_PATH=$(pwd)

# ===============================
# PROYECTO SN
# ===============================
SN_BASE="/etc/SN"
XRAY_GO="$SN_BASE/Sistema/xray-go.sh"
XRAY_DIR="/etc/xray"

[[ -f /etc/redhat-release && -z $(echo $SHELL | grep zsh) ]] && unalias -a
[[ -z $(echo $SHELL | grep zsh) ]] && ENV_FILE=".bashrc" || ENV_FILE=".zshrc"

# ===============================
# DEPENDENCIAS (LAS QUE REALMENTE USA)
# ===============================
dependencias() {
    soft="curl unzip jq uuid-runtime socat cron bash-completion ntpdate gawk"

    apt update -y >/dev/null 2>&1
    for pkg in $soft; do
        msg -nazu "Instalando $pkg"
        apt install -y $pkg >/dev/null 2>&1 \
            && msg -verd "OK" \
            || msg -verm2 "FAIL"
    done
    msg -bar
}

# ===============================
# DESACTIVAR SELINUX (IGUAL QUE ORIGINAL)
# ===============================
closeSELinux() {
    if [[ -s /etc/selinux/config ]] && grep -q enforcing /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
        setenforce 0 2>/dev/null
    fi
}

# ===============================
# SINCRONIZAR TIEMPO
# ===============================
timeSync() {
    print_center -blu "Sincronizando tiempo..."
    command -v ntpdate >/dev/null && ntpdate pool.ntp.org
    command -v chronyc >/dev/null && chronyc -a makestep
    print_center -ama "Hora actual: $(date -R)"
    msg -bar
}

# ===============================
# INSTALAR XRAY (EQUIVALENTE A go.sh)
# ===============================
updateProject() {
    print_center -ama "Instalando XRAY Core"

    if [[ ! -f "$XRAY_GO" ]]; then
        print_center -verm2 "No existe $XRAY_GO"
        exit 1
    fi

    chmod +x "$XRAY_GO"
    bash "$XRAY_GO"
}

# ===============================
# INICIALIZAR ENTORNO (IGUAL QUE ORIGINAL)
# ===============================
profileInit() {
    grep -q PYTHONIOENCODING ~/.bashrc || \
        echo "export PYTHONIOENCODING=utf-8" >> ~/.bashrc
    source ~/.bashrc 2>/dev/null
}

# ===============================
# MODIFICAR CONFIG (WS + PATH)
# ===============================
installFinish() {
    cd "$BEGIN_PATH"

    CFG="$XRAY_DIR/config.json"
    TMP="$XRAY_DIR/tmp.json"

    [[ ! -f "$CFG" ]] && {
        print_center -verm2 "No se encontró config.json de XRAY"
        return
    }

    # eliminar kcp si existe (igual que original)
    jq 'del(.inbounds[].streamSettings.kcpSettings)' "$CFG" > "$TMP"

    # agregar WS
    jq '.inbounds[].streamSettings += {
        "network":"ws",
        "wsSettings":{
            "path":"/SN/",
            "headers":{"Host":"ejemplo.com"}
        }
    }' "$TMP" > "$CFG"

    chmod 644 "$CFG"
    rm -f "$TMP"

    systemctl restart xray

    msg -bar
    if systemctl is-active --quiet xray; then
        print_center -verd "INSTALACIÓN FINALIZADA"
    else
        print_center -verm2 "XRAY instalado, pero falló el inicio"
    fi

    print_center -ama "Revise logs: journalctl -u xray"
    enter
}

# ===============================
# MAIN (MISMO ORDEN)
# ===============================
main() {
    title "INSTALADOR XRAY - SN"

    dependencias
    closeSELinux
    timeSync
    updateProject
    profileInit
    installFinish
}

main
