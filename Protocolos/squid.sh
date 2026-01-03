#!/bin/bash
set -euo pipefail

# =========================================================
# SinNombre v1.0 - SQUID (Proxy) Estilo ADMRufu (Rufu99)
# Archivo: SN/Protocolos/squid.sh
# =========================================================

R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
B='\033[0;34m'
C='\033[0;36m'
W='\033[1;37m'
N='\033[0m'
D='\033[2m'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

pause(){ echo ""; read -r -p "Presiona Enter para continuar..."; }
hr(){ echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"; }
sep(){ echo -e "${R}------------------------------------------------------------${N}"; }

require_root(){ [[ "${EUID:-$(id -u)}" -eq 0 ]] || { echo -e "${R}Ejecuta como root.${N}"; exit 1; }; }

mportas() {
  ss -H -lnt 2>/dev/null | awk '{print $4}' | awk -F: '{print $NF}' | sort -n | uniq
}

fun_ip(){
  curl -fsS --max-time 2 ifconfig.me 2>/dev/null || echo "127.0.0.1"
}

lshost(){
  payload="/etc/dominio-denie"
  [[ ! -f "$payload" ]] && return
  n=1
  for i in $(cat "$payload" | awk -F "/" '{print $1,$2,$3,$4}'); do
    echo -e " ${G}[$n]${N} ${W}>${N} ${C}$i${N}"
    pay[$n]="$i"
    ((n++))
  done
}

lsexpre(){
  payload2="/etc/exprecion-denie"
  [[ ! -f "$payload2" ]] && return
  n=1
  while read -r line; do
    echo -e " ${G}[$n]${N} ${W}>${N} ${C}$line${N}"
    pay[$n]="$line"
    ((n++))
  done <<< "$(cat "$payload2")"
}

fun_squid(){
  var_squid=""
  mipatch=""
  if [[ -e /etc/squid/squid.conf ]]; then
    var_squid="/etc/squid/squid.conf"
    mipatch="/etc/squid"
  elif [[ -e /etc/squid3/squid.conf ]]; then
    var_squid="/etc/squid3/squid.conf"
    mipatch="/etc/squid3"
  fi

  [[ -n "$var_squid" && -e "$var_squid" ]] && {
    clear
    hr
    echo -e "${Y}Removiendo Squid...${N}"
    hr

    [[ -d "/etc/squid" ]] && {
      systemctl stop squid >/dev/null 2>&1 || service squid stop >/dev/null 2>&1
      apt-get remove squid -y >/dev/null 2>&1
      apt-get purge squid -y >/dev/null 2>&1
      rm -rf /etc/squid >/dev/null 2>&1
    }

    [[ -d "/etc/squid3" ]] && {
      systemctl stop squid3 >/dev/null 2>&1 || service squid3 stop >/dev/null 2>&1
      apt-get remove squid3 -y >/dev/null 2>&1
      apt-get purge squid3 -y >/dev/null 2>&1
      rm -rf /etc/squid3 >/dev/null 2>&1
    }
    clear
    hr
    echo -e "${G}Squid removido con exito!${N}"
    hr
    [[ -e "$var_squid" ]] && rm -rf "$var_squid"
    [[ -e /etc/dominio-denie ]] && rm -rf /etc/dominio-denie
    [[ -e /etc/exprecion-denie ]] && rm -rf /etc/exprecion-denie
    sleep 1
    pause
    return
  }

  clear
  hr
  echo -e "${W}          INSTALADOR SQUID VPS-SN${N}"
  hr
  echo -e "${C}Digite los puertos separados por espacio${N}"
  echo -e "${Y}Ejemplo: 80 8080 8799 3128${N}"
  hr
  PORT=""
  while [[ -z "$PORT" ]]; do
    echo -ne "${W}Digite los Puertos: ${G}"
    read -r PORT
    tput cuu1 && tput dl1
    # Validar cada puerto
    invalid=""
    for p in $PORT; do
      if ! [[ "$p" =~ ^[0-9]+$ ]] || [[ $(mportas | grep -w "$p") != "" ]]; then
        invalid="yes"
        break
      fi
    done
    if [[ -n "$invalid" ]]; then
      echo -e "${Y}Uno o mas puertos invalidos o en uso${N}"
      sleep 2
      tput cuu1 && tput dl1
      PORT=""
    else
      echo -e "${Y}Puertos OK: $PORT${N}"
    fi
  done

  hr
  echo -e "${W}Instalando Squid...${N}"
  hr
  apt-get update -y >/dev/null 2>&1
  apt-get install squid -y >/dev/null 2>&1
  hr
  echo -e "${W}Iniciando configuracion...${N}"

  cat <<-EOF > /etc/dominio-denie
.ejemplo.com/
EOF

  cat <<-EOF > /etc/exprecion-denie
torrent
EOF

  unset var_squid
  if [[ -d /etc/squid ]]; then
    var_squid="/etc/squid/squid.conf"
  elif [[ -d /etc/squid3 ]]; then
    var_squid="/etc/squid3/squid.conf"
  fi

  ip=$(fun_ip)

  cat <<-EOF > "$var_squid"
#Configuracion SquiD
acl localhost src 127.0.0.1/32 ::1
acl to_localhost dst 127.0.0.0/8 0.0.0.0/32 ::1
acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 21
acl Safe_ports port 443
acl Safe_ports port 70
acl Safe_ports port 210
acl Safe_ports port 1025-65535
acl Safe_ports port 280
acl Safe_ports port 488
acl Safe_ports port 591
acl Safe_ports port 777
acl CONNECT method CONNECT
acl SSH dst $ip-$ip/255.255.255.255
acl exprecion-denie url_regex '/etc/exprecion-denie'
acl dominio-denie dstdomain '/etc/dominio-denie'
http_access deny exprecion-denie
http_access deny dominio-denie
http_access allow SSH
http_access allow manager localhost
http_access deny manager
http_access allow localhost

#puertos
EOF

  for pts in $PORT; do
    echo -e "http_port $pts" >> "$var_squid"
    [[ -f "/usr/sbin/ufw" ]] && ufw allow "$pts"/tcp &>/dev/null 2>&1
  done

  cat <<-EOF >> "$var_squid"
http_access allow all
coredump_dir /var/spool/squid
refresh_pattern ^ftp: 1440 20% 10080
refresh_pattern ^gopher: 1440 0% 1440
refresh_pattern -i (/cgi-bin/|\?) 0 0% 0
refresh_pattern . 0 20% 4320

#Nombre Squid
visible_hostname VPS-SN
EOF

  echo -e "${W}Reiniciando servicios...${N}"

  [[ -d "/etc/squid/" ]] && {
    systemctl restart ssh >/dev/null 2>&1 || service ssh restart >/dev/null 2>&1
    systemctl start squid >/dev/null 2>&1 || /etc/init.d/squid start >/dev/null 2>&1
    systemctl restart squid >/dev/null 2>&1 || service squid restart >/dev/null 2>&1
  }

  [[ -d "/etc/squid3/" ]] && {
    systemctl restart ssh >/dev/null 2>&1 || service ssh restart >/dev/null 2>&1
    systemctl start squid3 >/dev/null 2>&1 || /etc/init.d/squid3 start >/dev/null 2>&1
    systemctl restart squid3 >/dev/null 2>&1 || service squid3 restart >/dev/null 2>&1
  }

  sleep 2
  tput cuu1 && tput dl1
  echo -e "${G}SQUID INSTALADO Y CONFIGURADO${N}"
  pause
}

add_host(){
  payload="/etc/dominio-denie"
  clear
  hr
  echo -e "${W}Hosts Actuales Dentro del Squid${N}"
  hr
  lshost
  sep

  hos=""
  while [[ ! "$hos" =~ ^\. ]]; do
    echo -ne "${W}Digita un nuevo host: ${G}"
    read -r hos
    [[ "$hos" = "0" ]] && return
    tput cuu1 && tput dl1
    [[ "$hos" =~ ^\. ]] && continue
    echo -e "${Y}El host deve comensar con .punto.com${N}"
    sleep 3
    tput cuu1 && tput dl1
  done

  host="$hos/"
  [[ -z "$host" ]] && return

  if [[ $(grep -c "^$host" "$payload") -eq 1 ]]; then
    echo -e "${Y}El host ya existe${N}"
    pause
    return
  fi

  echo "$host" >> "$payload" && grep -v "^$" "$payload" > /tmp/a && mv /tmp/a "$payload"
  clear
  hr
  echo -e "${G}Host Agregado con Exito${N}"
  hr
  lshost
  hr
  echo -e "${W}Reiniciando servicios...${N}"

  if [[ ! -f "/etc/init.d/squid" ]]; then
    systemctl reload squid >/dev/null 2>&1 || service squid reload >/dev/null 2>&1
    systemctl restart squid >/dev/null 2>&1 || service squid restart >/dev/null 2>&1
  else
    /etc/init.d/squid reload >/dev/null 2>&1 || service squid reload >/dev/null 2>&1
    systemctl restart squid >/dev/null 2>&1 || service squid restart >/dev/null 2>&1
  fi

  tput cuu1 && tput dl1
  pause
}

add_expre(){
  payload2="/etc/exprecion-denie"
  clear
  hr
  echo -e "${W}Expresiones regulares Dentro de Squid${N}"
  hr
  lsexpre
  sep

  hos=""
  while [[ -z "$hos" ]]; do
    echo -ne "${W}Digita una palabra: ${G}"
    read -r hos
    [[ "$hos" = "0" ]] && return
    tput cuu1 && tput dl1
    [[ -n "$hos" ]] && continue
    echo -e "${Y}Escriba una palabra regular. Ej: torrent${N}"
    sleep 3
    tput cuu1 && tput dl1
  done

  host="$hos"
  [[ -z "$host" ]] && return

  if [[ $(grep -c "^$host" "$payload2") -eq 1 ]]; then
    echo -e "${Y}Expresion regular ya existe${N}"
    pause
    return
  fi

  echo "$host" >> "$payload2" && grep -v "^$" "$payload2" > /tmp/a && mv -f /tmp/a "$payload2"
  clear
  hr
  echo -e "${G}Expresion regular Agregada con Exito${N}"
  hr
  lsexpre
  hr
  echo -e "${W}Reiniciando servicios...${N}"

  if [[ ! -f "/etc/init.d/squid" ]]; then
    systemctl reload squid >/dev/null 2>&1 || service squid reload >/dev/null 2>&1
    systemctl restart squid >/dev/null 2>&1 || service squid restart >/dev/null 2>&1
  else
    /etc/init.d/squid reload >/dev/null 2>&1 || service squid reload >/dev/null 2>&1
    systemctl restart squid >/dev/null 2>&1 || service squid restart >/dev/null 2>&1
  fi

  tput cuu1 && tput dl1
  pause
}

del_host(){
  payload="/etc/dominio-denie"
  unset opcion
  clear
  hr
  echo -e "${W}Hosts Actuales Dentro del Squid${N}"
  hr
  lshost
  sep

  opcion=""
  while [[ -z "$opcion" ]]; do
    echo -ne "${W}Eliminar el host numero: ${G}"
    read -r opcion
    tput cuu1 && tput dl1
    if [[ ! "$opcion" =~ ^[0-9]+$ ]]; then
      echo -e "${R}Ingresa solo numeros${N}"
      sleep 2
      tput cuu1 && tput dl1
      opcion=""
    elif [[ "$opcion" -gt "${#pay[@]}" ]]; then
      echo -e "${Y}Solo numeros entre 0 y ${#pay[@]}${N}"
      sleep 2
      tput cuu1 && tput dl1
      opcion=""
    fi
  done
  [[ "$opcion" = "0" ]] && return
  host="${pay[$opcion]}/"
  [[ -z "$host" ]] && return
  [[ $(grep -c "^$host" "$payload") -ne 1 ]] && echo -e "${Y}Host No Encontrado${N}" && return
  grep -v "^$host" "$payload" > /tmp/a && mv /tmp/a "$payload"
  clear
  hr
  echo -e "${G}Host Removido Con Exito${N}"
  hr
  lshost
  hr
  echo -e "${W}Reiniciando servicios...${N}"

  if [[ ! -f "/etc/init.d/squid" ]]; then
    systemctl reload squid >/dev/null 2>&1 || service squid reload >/dev/null 2>&1
    systemctl restart squid >/dev/null 2>&1 || service squid restart >/dev/null 2>&1
  else
    /etc/init.d/squid reload >/dev/null 2>&1 || service squid reload >/dev/null 2>&1
    systemctl restart squid >/dev/null 2>&1 || service squid restart >/dev/null 2>&1
  fi

  tput cuu1 && tput dl1
  pause
}

del_expre(){
  payload2="/etc/exprecion-denie"
  unset opcion
  clear
  hr
  echo -e "${W}Expresion regular Dentro del Squid${N}"
  hr
  lsexpre
  sep

  opcion=""
  while [[ -z "$opcion" ]]; do
    echo -ne "${W}Eliminar la palabra numero: ${G}"
    read -r opcion
    tput cuu1 && tput dl1
    if [[ ! "$opcion" =~ ^[0-9]+$ ]]; then
      echo -e "${R}Ingresa solo numeros${N}"
      sleep 2
      tput cuu1 && tput dl1
      opcion=""
    elif [[ "$opcion" -gt "${#pay[@]}" ]]; then
      echo -e "${Y}Solo numeros entre 0 y ${#pay[@]}${N}"
      sleep 2
      tput cuu1 && tput dl1
      opcion=""
    fi
  done
  [[ "$opcion" = "0" ]] && return
  host="${pay[$opcion]}"
  [[ -z "$host" ]] && return
  [[ $(grep -c "^$host" "$payload2") -ne 1 ]] && echo -e "${Y}Palabra No Encontrada${N}" && return
  grep -v "^$host" "$payload2" > /tmp/a && mv -f /tmp/a "$payload2"
  clear
  hr
  echo -e "${G}Palabra Removida Con Exito${N}"
  hr
  lsexpre
  hr
  echo -e "${W}Reiniciando servicios...${N}"

  if [[ ! -f "/etc/init.d/squid" ]]; then
    systemctl reload squid >/dev/null 2>&1 || service squid reload >/dev/null 2>&1
    systemctl restart squid >/dev/null 2>&1 || service squid restart >/dev/null 2>&1
  else
    /etc/init.d/squid reload >/dev/null 2>&1 || service squid reload >/dev/null 2>&1
    systemctl restart squid >/dev/null 2>&1 || service squid restart >/dev/null 2>&1
  fi

  tput cuu1 && tput dl1
  pause
}

add_port(){
  if [[ -e /etc/squid/squid.conf ]]; then
    CONF="/etc/squid/squid.conf"
  elif [[ -e /etc/squid3/squid.conf ]]; then
    CONF="/etc/squid3/squid.conf"
  fi
  miport=$(grep -w 'http_port' "$CONF" | awk '{print $2}' | tr '\n' ' ')
  line=$(grep -n 'http_port' "$CONF" | head -1 | cut -d':' -f1)
  NEWCONF=$(sed "$line c VPS_port" "$CONF" | sed '/http_port/d')
  clear
  hr
  echo -e "${W}AGREGAR UN PUERTOS SQUID${N}"
  hr
  echo -e "${Y}Ingrese Sus Puertos: 80 8080 8799 3128${N}"
  hr
  echo -ne "${W}Digite Puertos: ${G}"
  read -r DPORT
  tput cuu1 && tput dl1
  TTOTAL=($DPORT)
  PORT=""
  for ((i=0; i<${#TTOTAL[@]}; i++)); do
    if [[ $(mportas | grep -v squid | grep -v '>' | grep -w "${TTOTAL[$i]}") = "" ]]; then
      echo -e "${Y}Puerto Elegido: ${G}${TTOTAL[$i]} OK${N}"
      PORT="$PORT ${TTOTAL[$i]}"
    else
      echo -e "${Y}Puerto Elegido: ${R}${TTOTAL[$i]} FAIL${N}"
    fi
  done
  [[ -z "$PORT" ]] && {
    hr
    echo -e "${R}Ningun Puerto Valido${N}"
    return
  }
  PORT="$miport $PORT"
  rm "$CONF"
  while read -r varline; do
    if [[ -n "$(echo "$varline" | grep 'VPS_port')" ]]; then
      for i in $PORT; do
        echo -e "http_port $i" >> "$CONF"
        ufw allow "$i"/tcp &>/dev/null 2>&1
      done
      continue
    fi
    echo -e "$varline" >> "$CONF"
  done <<< "$NEWCONF"
  hr
  echo -e "${W}AGUARDE REINICIANDO SERVICIOS${N}"
  [[ -d "/etc/squid/" ]] && {
    systemctl restart ssh >/dev/null 2>&1 || service ssh restart >/dev/null 2>&1
    systemctl start squid >/dev/null 2>&1 || /etc/init.d/squid start >/dev/null 2>&1
    systemctl restart squid >/dev/null 2>&1 || service squid restart >/dev/null 2>&1
  }
  [[ -d "/etc/squid3/" ]] && {
    systemctl restart ssh >/dev/null 2>&1 || service ssh restart >/dev/null 2>&1
    systemctl start squid3 >/dev/null 2>&1 || /etc/init.d/squid3 start >/dev/null 2>&1
    systemctl restart squid3 >/dev/null 2>&1 || service squid3 restart >/dev/null 2>&1
  }
  sleep 2
  tput cuu1 && tput dl1
  echo -e "${G}PUERTOS AGREGADOS${N}"
  pause
}

del_port(){
  squidport=$(lsof -V -i tcp -P -n | grep -v "ESTABLISHED" | grep -v "COMMAND" | grep "LISTEN" | grep -E 'squid|squid3')

  if [[ $(echo "$squidport" | wc -l) -lt 2 ]]; then
    clear
    hr
    echo -e "${Y}Un solo puerto para eliminar${N}"
    echo -e "${Y}Desea detener el servicio?${N}"
    hr
    echo -ne "${W}Opcion [S/N]: ${G}"
    read -r a
    tput cuu1 && tput dl1

    if [[ "$a" = @(S|s) ]]; then
      echo -e "${W}AGUARDE DETENIENDO SERVICIOS${N}"
      [[ -d "/etc/squid/" ]] && {
        if systemctl stop squid &>/dev/null || service squid stop &>/dev/null; then
          echo -e "${G}Servicio squid detenido${N}"
        else
          echo -e "${R}Falla al detener Servicio squid${N}"
        fi
      }
      [[ -d "/etc/squid3/" ]] && {
        if systemctl stop squid3 &>/dev/null || service squid3 stop &>/dev/null; then
          echo -e "${G}Servicio squid3 detenido${N}"
        else
          echo -e "${R}Falla al detener Servicio squid3${N}"
        fi
      }
    fi
    pause
    return
  fi

  if [[ -e /etc/squid/squid.conf ]]; then
    CONF="/etc/squid/squid.conf"
  elif [[ -e /etc/squid3/squid.conf ]]; then
    CONF="/etc/squid3/squid.conf"
  fi
  clear
  hr
  echo -e "${W}Quitar un puerto squid${N}"
  hr
  n=1
  while read -r i; do
    port=$(echo "$i" | awk '{print $9}' | cut -d':' -f2)
    echo -e " ${G}[$n]${N} ${W}>${N} ${C}$port${N}"
    drop[$n]="$port"
    num_opc="$n"
    ((n++))
  done <<< "$squidport"
  sep

  opc=""
  while [[ -z "$opc" ]]; do
    echo -ne "${W}Opcion: ${G}"
    read -r opc
    tput cuu1 && tput dl1
    if [[ -z "$opc" ]]; then
      echo -e "${R}Selecciona una opcion entre 1 y $num_opc${N}"
      sleep 2
      tput cuu1 && tput dl1
      opc=""
      continue
    elif [[ ! "$opc" =~ ^[0-9]+$ ]]; then
      echo -e "${R}Selecciona solo numeros entre 1 y $num_opc${N}"
      sleep 2
      tput cuu1 && tput dl1
      opc=""
      continue
    elif [[ "$opc" -gt "$num_opc" ]]; then
      echo -e "${R}Selecciona una opcion entre 1 y $num_opc${N}"
      sleep 2
      tput cuu1 && tput dl1
      opc=""
      continue
    fi
  done

  sed -i "/http_port ${drop[$opc]}/d" "$CONF"
  echo -e "${W}AGUARDE REINICIANDO SERVICIOS${N}"
  [[ -d "/etc/squid/" ]] && {
    systemctl restart ssh >/dev/null 2>&1 || service ssh restart >/dev/null 2>&1
    systemctl start squid >/dev/null 2>&1 || /etc/init.d/squid start >/dev/null 2>&1
    systemctl restart squid >/dev/null 2>&1 || service squid restart >/dev/null 2>&1
  }
  [[ -d "/etc/squid3/" ]] && {
    systemctl restart ssh >/dev/null 2>&1 || service ssh restart >/dev/null 2>&1
    systemctl start squid3 >/dev/null 2>&1 || /etc/init.d/squid3 start >/dev/null 2>&1
    systemctl restart squid3 >/dev/null 2>&1 || service squid3 restart >/dev/null 2>&1
  }
  sleep 2
  tput cuu1 && tput dl1
  echo -e "${G}PUERTO REMOVIDO${N}"
  pause
}

restart_squid(){
  clear
  hr
  echo -e "${W}AGUARDE REINICIANDO SERVICIOS${N}"
  [[ -d "/etc/squid/" ]] && {
    systemctl restart ssh >/dev/null 2>&1 || service ssh restart >/dev/null 2>&1
    systemctl start squid >/dev/null 2>&1 || /etc/init.d/squid start >/dev/null 2>&1
    systemctl restart squid >/dev/null 2>&1 || service squid restart >/dev/null 2>&1
  }
  [[ -d "/etc/squid3/" ]] && {
    systemctl restart ssh >/dev/null 2>&1 || service ssh restart >/dev/null 2>&1
    systemctl start squid3 >/dev/null 2>&1 || /etc/init.d/squid3 start >/dev/null 2>&1
    systemctl restart squid3 >/dev/null 2>&1 || service squid3 restart >/dev/null 2>&1
  }
  sleep 2
  tput cuu1 && tput dl1
  echo -e "${G}SERVICIO REINICIADO${N}"
  pause
}

online_squid(){
  payload="/etc/dominio-denie"
  payload2="/etc/exprecion-denie"
  while true; do
    clear
    hr
    echo -e "${W}      CONFIGURACION DE SQUID${N}"
    hr
    echo -e "${R}[${Y}1${R}]${N} ${C}Bloquear un host${N}"
    echo -e "${R}[${Y}2${R}]${N} ${C}Desbloquear un host${N}"
    echo -e "${R}[${Y}3${R}]${N} ${C}Bloquear expresion regular${N}"
    echo -e "${R}[${Y}4${R}]${N} ${C}Desbloquear expresion regular${N}"
    echo -e "${R}[${Y}5${R}]${N} ${C}Agregar puerto${N}"
    echo -e "${R}[${Y}6${R}]${N} ${C}Quitar puerto${N}"
    echo -e "${R}[${Y}7${R}]${N} ${R}Desinstalar Squid${N}"
    echo -e "${R}[${Y}8${R}]${N} ${Y}Reiniciar squid${N}"
    hr
    echo -e "${R}[${Y}0${R}]${N} ${W}VOLVER${N}"
    hr
    echo ""
    echo -ne "${W}Selecciona una opcion: ${G}"
    read -r opcion

    case "${opcion:-}" in
      1) add_host ;;
      2) del_host ;;
      3) add_expre ;;
      4) del_expre ;;
      5) add_port ;;
      6) del_port ;;
      7) fun_squid ;;
      8) restart_squid ;;
      0) break ;;
      *) echo -e "${B}Opcion invalida${N}"; sleep 1 ;;
    esac
  done
}

main_menu(){
  require_root

  if [[ -e /etc/squid/squid.conf ]] || [[ -e /etc/squid3/squid.conf ]]; then
    online_squid
  else
    fun_squid
    # Después de instalar, ir al menú si se instaló
    if [[ -e /etc/squid/squid.conf ]] || [[ -e /etc/squid3/squid.conf ]]; then
      online_squid
    fi
  fi
}
main_menu
