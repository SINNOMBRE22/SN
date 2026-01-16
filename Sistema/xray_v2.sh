#!/bin/bash

BEIJING_UPDATE_TIME=3
BEGIN_PATH=$(pwd)

[[ -f /etc/redhat-release && -z $(echo $SHELL|grep zsh) ]] && unalias -a
[[ -z $(echo $SHELL|grep zsh) ]] && ENV_FILE=".bashrc" || ENV_FILE=".zshrc"

dependencias(){
        soft="socat cron bash-completion ntpdate gawk jq uuid-runtime python-pip python3 python3-pip"

        for install in $soft; do
                leng="${#install}" 
                puntos=$(( 21 - $leng))
                pts="."
                for (( a = 0; a < $puntos; a++ )); do
                        pts+="."
                done
                msg -nazu "      instalando $install $(msg -ama "$pts")"
                if apt install $install -y &>/dev/null ; then
                        msg -verd "INSTALL"
                else
                        msg -verm2 "FAIL"
                        sleep 2
                        del 1
                        if [[ $install = "python" ]]; then
                                pts=$(echo ${pts:1})
                                msg -nazu "      instalando python2 $(msg -ama "$pts")"
                                if apt install python2 -y &>/dev/null ; then
                                        [[ ! -e /usr/bin/python ]] && ln -s /usr/bin/python2 /usr/bin/python
                                        msg -verd "INSTALL"
                                else
                                        msg -verm2 "FAIL"
                                fi
                                continue
                        fi
                        print_center -ama "aplicando fix a $install"
                        dpkg --configure -a &>/dev/null
                        sleep 2
                        del 1
                        msg -nazu "      instalando $install $(msg -ama "$pts")"
                        if apt install $install -y &>/dev/null ; then
                                msg -verd "INSTALL"
                        else
                                msg -verm2 "FAIL"
                        fi
                fi
        done

        if [[ ! -e '/usr/bin/pip' ]]; then
                _pip=$(type -p pip)
                ln -s "$._pip" /usr/bin/pip
        fi
        if [[ ! -e '/usr/bin/pip3' ]]; then
                _pip3=$(type -p pip3)
                ln -s "$._pip3" /usr/bin/pip3
        fi
        msg -bar
}

closeSELinux(){
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

timeSync(){
        print_center -blu "Sincronización de tiempo ..."
        if [[ `command -v ntpdate` ]];then
                ntpdate pool.ntp.org
        elif [[ `command -v chronyc` ]];then
                chronyc -a makestep
        fi

        if [[ $? -eq 0 ]];then 
                print_center -blu "Éxito de sincronización de tiempo"
                print_center -ama "Actual : `date -R`"
        fi
        msg -bar
}

updateProject(){
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
    [[ -e /usr/share/bash-completion/completions/xray ]] && rm -f /usr/share/bash-completion/completions/xray
    curl -sSL https://raw.githubusercontent.com/XTLS/Xray-core/main/extra/bash_completion/xray > /usr/share/bash-completion/completions/xray
    if [[ -z $(echo $SHELL|grep zsh) ]];then
        source /usr/share/bash-completion/completions/xray
    fi
}

profileInit(){
    [[ $(grep xray ~/$ENV_FILE) ]] && sed -i '/xray/d' ~/$ENV_FILE && source ~/$ENV_FILE
    [[ -z $(grep PYTHONIOENCODING=utf-8 ~/$ENV_FILE) ]] && echo "export PYTHONIOENCODING=utf-8" >> ~/$ENV_FILE && source ~/$ENV_FILE
    # Config inicial con REALITY
    xray new &>/dev/null
}

installFinish(){
    cd ${BEGIN_PATH}

    config='/etc/xray/config.json'
    temp='/etc/xray/temp.json'
    # Configurar VLESS con REALITY por defecto
    jq '.inbounds[0].protocol = "vless"' < /etc/xray/config.json > /etc/xray/temp.json
    jq '.inbounds[0].settings.clients[0].id = "'$(uuidgen)'"' < /etc/xray/temp.json > /etc/xray/config.json
    jq '.inbounds[0].settings.clients[0].flow = "xtls-rprx-vision"' < /etc/xray/config.json > /etc/xray/temp.json
    mv /etc/xray/temp.json /etc/xray/config.json
    jq '.inbounds[0].streamSettings.security = "reality"' < /etc/xray/config.json > /etc/xray/temp.json
    mv /etc/xray/temp.json /etc/xray/config.json
    chmod 777 /etc/xray/config.json
    msg -bar
    if [[ $(xray restart|grep success) ]]; then
            xray info
            msg -bar
        print_center -verd "INSTALACION FINALIZADA"
    else
            xray info
            msg -bar
        print_center -verd "INSTALACION FINALIZADA"
        print_center -verm2 'Pero fallo el reinicio del servicio xray'
    fi
    print_center -ama "Por favor verifique el log"
    enter
}

main(){
        title 'INSTALADO DEPENDENCIAS XRAY'

    dependencias
    closeSELinux
    timeSync
    updateProject
    profileInit
    installFinish
}

main
