#!/bin/bash
set -euo pipefail

# COLORES
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'
B='\033[0;34m'; M='\033[0;35m'; C='\033[0;36m'
W='\033[1;37m'; N='\033[0m'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_DB="${ROOT_DIR}/panel_users.db"
BACKUP_DIR="${ROOT_DIR}/panel_backups"
mkdir -p "$BACKUP_DIR"
touch "$USER_DB"

hr() { echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"; }
hr_y() { echo -e "${Y}------------------------------------------------------------${N}"; }
pause() { echo ""; read -r -p "$(echo -e "${C}Presiona Enter para continuar...${N}")"; }

# ----------- AUTO-DETECCIÓN DE SERVICIOS ----------
get_ip() {
    curl -fs --max-time 4 ifconfig.me 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}' || echo "0.0.0.0"
}

ports_by_proc() {
    local re="$1"
    ss -H -lntp 2>/dev/null | awk -v r="$re" '$0 ~ r {print $4}' | awk -F: '{print $NF}' | sort -n | uniq | tr '\n' ' ' | sed 's/[[:space:]]\+$//' || true
}

ssh_ports() { local p; p="$(ports_by_proc '(sshd|ssh)')"; [[ -n "${p:-}" ]] && echo "$p" || echo "22"; }
dropbear_ports() { local p; p="$(ports_by_proc 'dropbear')"; [[ -n "${p:-}" ]] && echo "$p" || echo "-"; }
stunnel_ports() { local p; p="$(ports_by_proc 'stunnel4')"; [[ -n "${p:-}" ]] && echo "$p" || echo "-"; }
http_ports() {
    ss -lntp 2>/dev/null | awk '$0~/:(80|8080)/{print $4}' | awk -F: '{print $NF}' | sort -n | uniq | paste -sd, - || echo "-"
}
udp_ports() {
    ss -lunp 2>/dev/null | awk 'NR>1{print $5}' | awk -F: '{print $NF}' | sort -n | uniq | paste -sd, - || echo "-"
}

# ----------- FUNCIONES CRÍTICAS DEL SEGUNDO SCRIPT ----------
valid_user() { [[ "$1" =~ ^[a-zA-Z0-9._-]{4,20}$ ]]; }

openssl_hash() {
    # Igual que ADMRufu: según versión, usa -6 o -1
    local pass="$1"
    local ver
    ver="$(openssl version 2>/dev/null | awk '{print $2}' | cut -c1-5 || true)"
    if [[ "$ver" == "1.1.1" ]]; then
        openssl passwd -6 "$pass"
    else
        openssl passwd -1 "$pass"
    fi
}

# ------------- PANEL TICKET BONITO -----------------
ticket_bonito() {
    local usuario="$1" password="$2" expira="$3" limit="$4"
    local DOMINIO="dominio.ejemplo"   # Modifícalo si tienes alguno propio
    local VPS_NAME="VPS Panel SSH"
    local IP_SERVIDOR; IP_SERVIDOR="$(get_ip)"

    local P_SSH; P_SSH="$(ssh_ports)"
    local P_DROPBEAR; P_DROPBEAR="$(dropbear_ports)"
    local P_STUNNEL; P_STUNNEL="$(stunnel_ports)"
    local P_HTTP; P_HTTP="$(http_ports)"
    local P_UDP; P_UDP="$(udp_ports)"

    local PAYLOAD_HTTP="GET / HTTP/1.1
Host: $DOMINIO
Upgrade: websocket"
    local PAYLOAD_TLS="GET wss://bug_host/ HTTP/1.1
Host: $DOMINIO
Upgrade: websocket
Connection: Keep-Alive"

    local divider="\033[1;36m────────────────────────────────────\033[0m"

    echo -e "\033[1;33m$VPS_NAME\033[0m"
    echo -e "$divider"
    echo -e "\033[1;32mServidor\033[0m"
    echo -e "↳ \033[1;37mHost       \033[0m→ $DOMINIO"
    echo -e "↳ \033[1;37mIP         \033[0m→ $IP_SERVIDOR"
    echo -e "$divider"
    echo -e "\033[1;32mCuenta SSH\033[0m"
    echo -e "↳ \033[1;37mUsuario    \033[0m→ $usuario"
    echo -e "↳ \033[1;37mContraseña \033[0m→ $password"
    echo -e "↳ \033[1;37mLímite     \033[0m→ $limit conexiones"
    echo -e "↳ \033[1;37mExpira     \033[0m→ $expira"
    echo -e "$divider"
    echo -e "\033[1;32mServicios\033[0m"
    echo -e "↳ \033[1;37mSSH        \033[0m→ $P_SSH"
    echo -e "↳ \033[1;37mTLS / SSL  \033[0m→ $P_STUNNEL"
    echo -e "↳ \033[1;37mDropbear   \033[0m→ $P_DROPBEAR"
    echo -e "↳ \033[1;37mHTTP       \033[0m→ $P_HTTP"
    echo -e "↳ \033[1;37mUDP        \033[0m→ $P_UDP"
    echo -e "$divider"
    echo -e "\033[1;32mPayload · HTTP\033[0m"
    while read -r line; do echo -e "↳ $line"; done <<< "$(echo -e "$PAYLOAD_HTTP")"
    echo -e "$divider"
    echo -e "\033[1;32mPayload · TLS\033[0m"
    while read -r line; do echo -e "↳ $line"; done <<< "$(echo -e "$PAYLOAD_TLS")"
    echo -e "$divider"
}

# ========= FUNCIONES PANEL MODIFICADAS ===========

nuevo_usuario() {
    clear; hr
    echo -e "${W}                    NUEVO USUARIO SSH${N}"
    hr
    read -rp "$(echo -e "${Y}Usuario (4-20): ${N}")" u
    valid_user "${u:-}" || { echo -e "${R}Usuario inválido (4-20 caracteres alfanuméricos).${N}"; pause; return; }
    
    if grep -qE "^${u}\|" "$USER_DB" || id "$u" &>/dev/null; then
        echo -e "${R}⛔ Usuario ya existe en panel o sistema.${N}"; pause; return
    fi

    read -rp "$(echo -e "${Y}Contraseña (4-12): ${N}")" p
    [[ -n "$p" ]] && (( ${#p} >= 4 && ${#p} <= 12 )) || { echo -e "${R}Contraseña inválida (4-12 caracteres).${N}"; pause; return; }

    read -rp "$(echo -e "${Y}Duración en días (1-365): ${N}")" days
    [[ "$days" =~ ^[0-9]+$ ]] && ((days >= 1 && days <= 365)) || { echo -e "${R}Días inválidos (1-365).${N}"; pause; return; }

    read -rp "$(echo -e "${Y}Límite de conexión (1-999): ${N}")" limit
    [[ "$limit" =~ ^[0-9]+$ ]] && ((limit >= 1 && limit <= 999)) || { echo -e "${R}Límite inválido (1-999).${N}"; pause; return; }

    fecha_exp=$(date '+%C%y-%m-%d' -d "+$days days")
    hash_pass="$(openssl_hash "$p")"
    
    # MÉTODO QUE SÍ CONECTA (igual al segundo script)
    useradd -M -s /bin/false -p "${hash_pass}" -c "${limit},${p}" "${u}" >/dev/null 2>&1 || {
        echo -e "${R}Error: no se pudo crear usuario.${N}"; pause; return
    }
    chage -E "${fecha_exp}" -W 0 "${u}" >/dev/null 2>&1 || true
    
    # Guardar en base de datos del panel
    echo "$u|$p|$fecha_exp|$limit" >> "$USER_DB"

    clear
    ticket_bonito "$u" "$p" "$fecha_exp" "$limit"
    pause
}

remover_usuario() {
    clear; hr
    echo -e "${W}        REMOVER USUARIO (SELECCIONA NÚMERO)${N}"
    hr_y
    declare -a arr
    mapfile -t arr < <(while IFS='|' read -r u p f l; do id "$u" &>/dev/null && echo "$u|$p|$f|$l"; done < "$USER_DB")
    if [[ ${#arr[@]} -eq 0 ]]; then echo -e "${Y}No hay usuarios para eliminar.${N}"; pause; return; fi

    for i in "${!arr[@]}"; do
        u=$(echo "${arr[$i]}" | cut -d'|' -f1)
        p=$(echo "${arr[$i]}" | cut -d'|' -f2)
        f=$(echo "${arr[$i]}" | cut -d'|' -f3)
        l=$(echo "${arr[$i]}" | cut -d'|' -f4)
        printf "${R}[%s]${N} ${Y}%s${N} ${C}(pass:${W}%s${C}, exp:${W}%s${C}, límite:${W}%s${C})${N}\n" "$((i+1))" "$u" "$p" "$f" "$l"
    done
    hr_y
    read -rp "Elige qué usuario eliminar (número): " n
    [[ "$n" =~ ^[0-9]+$ && $n -ge 1 && $n -le ${#arr[@]} ]] || { echo -e "${R}Opción no válida.${N}"; pause; return; }
    usuario=$(echo "${arr[$((n-1))]}" | cut -d'|' -f1)
    pkill -u "$usuario" >/dev/null 2>&1 || true
    userdel --force "$usuario" >/dev/null 2>&1
    sed -i "/^${usuario}\|/d" "$USER_DB"
    echo -e "${G}Usuario eliminado: $usuario${N}"
    pause
}

seleccionar_usuario_con_detalle() {
    declare -a arr
    mapfile -t arr < <(while IFS='|' read -r u p f l; do id "$u" &>/dev/null && echo "$u|$p|$f|$l"; done < "$USER_DB")
    if [[ ${#arr[@]} -eq 0 ]]; then echo -e "${Y}No hay usuarios.${N}"; pause; return 1; fi
    for i in "${!arr[@]}"; do
        u=$(echo "${arr[$i]}" | cut -d'|' -f1)
        p=$(echo "${arr[$i]}" | cut -d'|' -f2)
        f=$(echo "${arr[$i]}" | cut -d'|' -f3)
        l=$(echo "${arr[$i]}" | cut -d'|' -f4)
        printf "${R}[%s]${N} ${Y}%s${N} ${C}(pass:${W}%s${C}, exp:${W}%s${C}, límite:${W}%s${C})${N}\n" "$((i+1))" "$u" "$p" "$f" "$l"
    done
    hr_y
    read -rp "Elige usuario (número, 0 para cancelar): " n
    [[ "$n" = "0" ]] && return 1
    [[ "$n" =~ ^[0-9]+$ && $n -ge 1 && $n -le ${#arr[@]} ]] || { echo -e "${R}Opción no válida.${N}"; pause; return 1; }
    echo "${arr[$((n-1))]}"
    return 0
}

renovar_usuario() {
    clear; hr
    echo -e "${W}                 RENOVAR USUARIO${N}"
    hr_y
    seleccionado=$(seleccionar_usuario_con_detalle) || return
    u=$(echo "$seleccionado" | cut -d'|' -f1)
    p=$(echo "$seleccionado" | cut -d'|' -f2)
    f=$(echo "$seleccionado" | cut -d'|' -f3)
    l=$(echo "$seleccionado" | cut -d'|' -f4)
    
    read -rp "Días a agregar (1-360): " days
    [[ "$days" =~ ^[0-9]+$ ]] && ((days >= 1 && days <= 360)) || { echo -e "${R}Cantidad inválida.${N}"; pause; return; }
    
    fecha_exp=$(date '+%C%y-%m-%d' -d "$f +$days days")
    chage -E "$fecha_exp" "$u" >/dev/null 2>&1
    
    sed -i "s/^${u}|[^|]*|[^|]*|[^|]*/${u}|$p|$fecha_exp|$l/" "$USER_DB"
    echo -e "${G}Usuario ${u} renovado hasta $fecha_exp${N}"
    pause
}

editar_usuario() {
    clear; hr
    echo -e "${W}                 EDITAR USUARIO${N}"
    hr_y
    seleccionado=$(seleccionar_usuario_con_detalle) || return
    u=$(echo "$seleccionado" | cut -d'|' -f1)
    p_old=$(echo "$seleccionado" | cut -d'|' -f2)
    f_old=$(echo "$seleccionado" | cut -d'|' -f3)
    l_old=$(echo "$seleccionado" | cut -d'|' -f4)
    
    read -rp "Nueva contraseña (ENTER para dejar igual): " npass
    [[ -z "$npass" ]] && npass="$p_old"
    [[ ${#npass} -ge 4 && ${#npass} -le 12 ]] || { echo -e "${R}Contraseña debe tener 4-12 caracteres.${N}"; pause; return; }
    
    read -rp "Nueva duración en días (ENTER deja igual): " ndias
    if [[ -z "$ndias" ]]; then
        fecha_exp="$f_old"
    else
        [[ "$ndias" =~ ^[0-9]+$ && $ndias -gt 0 && $ndias -le 365 ]] || { echo -e "${R}Días inválidos (1-365).${N}"; pause; return; }
        fecha_exp=$(date '+%C%y-%m-%d' -d "+$ndias days")
    fi
    
    read -rp "Nuevo límite (ENTER deja igual): " nlimit
    [[ -z "$nlimit" ]] && nlimit="$l_old"
    [[ "$nlimit" =~ ^[0-9]+$ && $nlimit -ge 1 && $nlimit -le 999 ]] || { echo -e "${R}Límite inválido (1-999).${N}"; pause; return; }
    
    # Actualizar usuario en sistema
    if [[ "$npass" != "$p_old" ]]; then
        hash_pass="$(openssl_hash "$npass")"
        usermod -p "${hash_pass}" -c "${nlimit},${npass}" "$u" >/dev/null 2>&1
    else
        # Solo actualizar el límite en el comment
        current_comment=$(getent passwd "$u" | cut -d: -f5)
        new_comment="${nlimit},${npass}"
        usermod -c "$new_comment" "$u" >/dev/null 2>&1
    fi
    
    chage -E "$fecha_exp" "$u" >/dev/null 2>&1
    sed -i "s/^${u}|[^|]*|[^|]*|[^|]*/${u}|$npass|$fecha_exp|$nlimit/" "$USER_DB"
    
    echo -e "${G}Usuario $u editado.${N}"
    pause
}

bloquear_usuario() {
    clear; hr
    echo -e "${W}           BLOQUEAR / DESBLOQUEAR USUARIO${N}"
    hr_y
    seleccionado=$(seleccionar_usuario_con_detalle) || return
    u=$(echo "$seleccionado" | cut -d'|' -f1)
    st=$(passwd --status "$u" 2>/dev/null | awk '{print $2}')
    if [[ "$st" == "P" ]]; then
        pkill -u "$u" >/dev/null 2>&1 || true
        usermod -L "$u" >/dev/null 2>&1
        echo -e "${Y}Usuario $u bloqueado.${N}"
    else
        usermod -U "$u" >/dev/null 2>&1
        echo -e "${G}Usuario $u desbloqueado.${N}"
    fi
    pause
}

detalles_todos_usuarios() {
    clear; hr
    echo -e "${W}             DETALLES DE TODOS LOS USUARIOS${N}"
    hr_y
    printf "${C}%-20s %-20s %-12s %-8s${N}\n" "USUARIO" "CONTRASEÑA" "EXPIRA" "LÍMITE"
    hr_y
    while IFS='|' read -r u p f l; do 
        id "$u" &>/dev/null && printf "%-20s %-20s %-12s %-8s\n" "$u" "$p" "$f" "$l"
    done < "$USER_DB"
    hr_y
    pause
}

eliminar_vencidos() {
    clear; hr
    echo -e "${W}             ELIMINAR USUARIOS VENCIDOS${N}"
    hr
    hoy=$(date +%Y-%m-%d)
    eliminar=""
    while IFS='|' read -r u _ f _; do 
        [[ "$f" < "$hoy" ]] && { 
            id "$u" &>/dev/null && {
                pkill -u "$u" >/dev/null 2>&1 || true
                userdel --force "$u" >/dev/null 2>&1
                eliminar+="$u "
                sed -i "/^$u|/d" "$USER_DB"
            }
        }
    done < "$USER_DB"
    [[ -z "$eliminar" ]] && echo -e "${G}No hay usuarios vencidos.${N}" || echo -e "${R}Eliminados: $eliminar${N}"
    pause
}

eliminar_todos() {
    clear; hr
    echo -e "${W}             ELIMINAR TODOS LOS USUARIOS${N}"
    hr
    echo -e "${R}¿Estás seguro de eliminar TODOS los usuarios? (s/n): ${N}"
    read -r confirm
    [[ "$confirm" != "s" && "$confirm" != "S" ]] && { echo "Cancelado."; pause; return; }
    
    while IFS='|' read -r u _ _ _; do 
        id "$u" &>/dev/null && {
            pkill -u "$u" >/dev/null 2>&1 || true
            userdel --force "$u" >/dev/null 2>&1
        }
    done < "$USER_DB"
    : > "$USER_DB"
    echo -e "${R}Todos los usuarios eliminados.${N}"
    pause
}

admin_copias() {
    clear; hr
    echo -e "${W}      ADMINISTRAR COPIAS DE USUARIOS${N}"
    hr
    echo "[1]> Realizar respaldo"
    echo "[2]> Restaurar respaldo" 
    echo "[3]> Ver lista de respaldos"
    echo "[0]> Volver"
    echo ""
    read -rp "Selecciona opción: " op
    case "$op" in
        1) fname="${BACKUP_DIR}/panel_users_$(date +%Y%m%d_%H%M%S).bak"
           cp "$USER_DB" "$fname"
           echo -e "${G}Respaldo guardado en: $fname${N}" ;;
        2) echo "Archivos de respaldo:"
           ls -1 "$BACKUP_DIR" 2>/dev/null || echo "No hay respaldos"
           read -rp "Archivo de respaldo a restaurar: " bak
           [[ -f "$BACKUP_DIR/$bak" ]] && {
               cp "$BACKUP_DIR/$bak" "$USER_DB"
               echo -e "${G}Base de datos restaurada.${N}"
           } || echo -e "${R}No existe el archivo.${N}" ;;
        3) ls -lh "$BACKUP_DIR" 2>/dev/null || echo "No hay respaldos" ;;
    esac
    pause
}

main_menu() {
    while true; do
        clear; hr
        echo -e "${M}         GESTIÓN DE USUARIOS SSH PANEL${N}"; hr
        echo -e "${R}[${Y}1${R}]${N} ${C}NUEVO USUARIO${N}"
        echo -e "${R}[${Y}2${R}]${N} ${C}REMOVER USUARIO${N}"
        echo -e "${R}[${Y}3${R}]${N} ${C}RENOVAR USUARIO${N}"
        echo -e "${R}[${Y}4${R}]${N} ${C}EDITAR USUARIO${N}"
        echo -e "${R}[${Y}5${R}]${N} ${C}BLOQUEAR/DESBLOQUEAR USUARIO${N}"; hr_y
        echo -e "${R}[${Y}6${R}]${N} ${C}CONFIGURAR CONTRASEÑA GENERAL${N}"; hr_y
        echo -e "${R}[${Y}7${R}]${N} ${C}DETALLES DE TODOS USUARIOS${N}"
        echo -e "${R}[${Y}8${R}]${N} ${C}MONITOR DE USUARIOS CONECTADOS${N}"
        echo -e "${R}[${Y}9${R}]${N} ${C}LIMITADOR-DE-CUENTAS${N}"; hr_y
        echo -e "${R}[${Y}10${R}]${N} ${C}ELIMINAR USUARIOS VENCIDOS${N}"
        echo -e "${R}[${Y}11${R}]${N} ${C}ELIMINAR TODOS LOS USUARIOS${N}"; hr_y
        echo -e "${R}[${Y}12${R}]${N} ${C}ADMINISTRACION COPIAS DE USUARIOS${N}"
        echo -e "${R}[${Y}13${R}]${N} ${C}DESACTIVAR CONTRASEÑA ALFANUMERICA${N}"; hr_y
        echo -e "${Y}[0]${N} Volver      ${Y}[14]${N} CAMBIAR A MODO SSH/HWID/TOKE"
        echo ""; read -rp "$(echo -e "${W}Ingresa una Opcion: ${G}")" op
        case "$op" in
            1) nuevo_usuario ;;
            2) remover_usuario ;;
            3) renovar_usuario ;;
            4) editar_usuario ;;
            5) bloquear_usuario ;;
            6) configurar_contra_gral ;;
            7) detalles_todos_usuarios ;;
            8) monitor_conectados ;;
            9) limitador_cuentas ;;
            10) eliminar_vencidos ;;
            11) eliminar_todos ;;
            12) admin_copias ;;
            13) desactivar_pass_alfanumerica ;;
            14) cambiar_modo ;;
            0) exit 0 ;;
            *) echo -e "${B}Opción inválida${N}"; sleep 1 ;;
        esac
    done
}

main_menu
