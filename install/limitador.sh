#!/bin/bash
# =========================================================
# SinNombre v2.0 - Limitador de Cuentas SSH
# Archivo: install/limitador.sh
# Ubicación esperada: /etc/SN/install/limitador.sh
#
# Uso:
#   /etc/SN/install/limitador.sh          → Limitador de conexiones (loop)
#   /etc/SN/install/limitador.sh --ssh    → Eliminar usuarios expirados (una vez)
# =========================================================

VPS_user="/etc/SN"
LOG_FILE="${VPS_user}/limit.log"

# Colores para log
R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
N='\033[0m'

# ── Crear archivos necesarios si no existen ─────────────
[[ ! -f "$LOG_FILE" ]] && touch "$LOG_FILE"

# ── Función: obtener IP pública ─────────────────────────
fun_ip() {
  curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}'
}

# ── Función: listar usuarios SSH del sistema ────────────
mostrar_usuarios() {
  grep 'home' /etc/passwd | grep 'false' | grep -v 'syslog' | grep -v 'hwid' | grep -v 'token' | awk -F ':' '{print $1}'
}

# ── Función: contar conexiones activas de un usuario ────
contar_conexiones() {
  local user="$1"
  local count=0

  # SSH (sshd)
  local sshd_count
  sshd_count=$(ps -u "$user" 2>/dev/null | grep -c sshd || echo 0)
  count=$((count + sshd_count))

  # Dropbear
  local drop_count
  drop_count=$(ps aux 2>/dev/null | grep -i dropbear | grep -w "$user" | grep -v grep | wc -l)
  count=$((count + drop_count))

  # OpenVPN
  if [[ -e /etc/openvpn/openvpn-status.log ]]; then
    local ovp_count
    ovp_count=$(grep -c ",$user," /etc/openvpn/openvpn-status.log 2>/dev/null || echo 0)
    count=$((count + ovp_count))
  fi

  echo "$count"
}

# ── Función: obtener límite de conexiones de un usuario ──
obtener_limite() {
  local user="$1"
  local limite
  limite=$(grep -w "$user" /etc/passwd | awk -F ':' '{print $5}' | cut -d ',' -f1)
  # Validar que sea un número
  if [[ "$limite" =~ ^[0-9]+$ ]] && [[ "$limite" -gt 0 ]]; then
    echo "$limite"
  else
    echo "0"  # 0 = sin límite
  fi
}

# ── Función: desbloquear usuarios bloqueados por el limitador ──
desbloquear_usuarios() {
  local unlock_file="${VPS_user}/limitador_bloqueados.txt"
  [[ ! -f "$unlock_file" ]] && return

  while IFS= read -r user; do
    [[ -z "$user" ]] && continue
    # Solo desbloquear si realmente está bloqueado
    if [[ "$(passwd --status "$user" 2>/dev/null | cut -d ' ' -f2)" = "L" ]]; then
      usermod -U "$user" 2>/dev/null
      local fecha_hora
      fecha_hora="$(date '+%Y-%m-%d %H:%M:%S')"
      echo "[$fecha_hora] DESBLOQUEADO: $user (automático)" >> "$LOG_FILE"
    fi
  done < "$unlock_file"

  # Limpiar la lista
  > "$unlock_file"
}

# =========================================================
# MODO 1: LIMITADOR DE EXPIRADOS (--ssh)
# Se ejecuta una sola vez y termina
# =========================================================
limitador_expirados() {
  local fecha_actual
  fecha_actual=$(date +%s)

  while IFS= read -r user; do
    [[ -z "$user" ]] && continue

    local fecha_exp
    fecha_exp=$(chage -l "$user" 2>/dev/null | sed -n '4p' | awk -F ': ' '{print $2}')

    # Saltar si nunca expira
    [[ "$fecha_exp" = @(never|nunca) ]] && continue
    [[ -z "$fecha_exp" ]] && continue

    local fecha_exp_sec
    fecha_exp_sec=$(date +%s --date="$fecha_exp" 2>/dev/null) || continue

    if [[ "$fecha_exp_sec" -lt "$fecha_actual" ]]; then
      # Usuario expirado → matar procesos y eliminar
      pkill -u "$user" 2>/dev/null
      # Matar dropbear del usuario
      local droplim
      droplim=$(ps aux | grep dropbear | grep -v grep | grep -w "$user" | awk '{print $2}')
      [[ -n "$droplim" ]] && kill -9 $droplim 2>/dev/null

      userdel --force "$user" 2>/dev/null
      sed -i "/$user/d" "${VPS_user}/passwd" 2>/dev/null

      local fecha_hora
      fecha_hora="$(date '+%Y-%m-%d %H:%M:%S')"
      echo "[$fecha_hora] EXPIRADO ELIMINADO: $user (vencido: $fecha_exp)" >> "$LOG_FILE"
    fi
  done <<< "$(mostrar_usuarios)"

  exit 0
}

# =========================================================
# MODO 2: LIMITADOR DE CONEXIONES (loop infinito)
# Se ejecuta en background cada X minutos
# =========================================================
limitador_conexiones() {
  local intervalo_limit intervalo_unlock
  local unlock_file="${VPS_user}/limitador_bloqueados.txt"

  # Leer configuración
  if [[ -f "${VPS_user}/limit" ]]; then
    intervalo_limit=$(cat "${VPS_user}/limit" 2>/dev/null)
  else
    intervalo_limit=5  # Default: cada 5 minutos
  fi

  if [[ -f "${VPS_user}/unlimit" ]]; then
    intervalo_unlock=$(cat "${VPS_user}/unlimit" 2>/dev/null)
  else
    intervalo_unlock=0  # Default: desbloqueo manual
  fi

  # Validar que sean números
  [[ ! "$intervalo_limit" =~ ^[0-9]+$ ]] && intervalo_limit=5
  [[ ! "$intervalo_unlock" =~ ^[0-9]+$ ]] && intervalo_unlock=0

  local ciclos_para_unlock=0
  local ciclo_actual=0

  # Calcular cada cuántos ciclos desbloquear
  if [[ "$intervalo_unlock" -gt 0 && "$intervalo_limit" -gt 0 ]]; then
    ciclos_para_unlock=$(( intervalo_unlock / intervalo_limit ))
    [[ "$ciclos_para_unlock" -lt 1 ]] && ciclos_para_unlock=1
  fi

  # Crear archivo de bloqueados si no existe
  [[ ! -f "$unlock_file" ]] && touch "$unlock_file"

  # ── Loop principal ────────────────────────────────────
  while true; do
    # Recorrer todos los usuarios SSH
    while IFS= read -r user; do
      [[ -z "$user" ]] && continue

      local limite conexiones
      limite=$(obtener_limite "$user")
      conexiones=$(contar_conexiones "$user")

      # Si el límite es 0, no limitar
      [[ "$limite" -eq 0 ]] && continue

      # Si las conexiones exceden el límite → BLOQUEAR
      if [[ "$conexiones" -gt "$limite" ]]; then
        # Solo bloquear si no está ya bloqueado
        if [[ "$(passwd --status "$user" 2>/dev/null | cut -d ' ' -f2)" = "P" ]]; then
          # Matar todas las sesiones del usuario
          pkill -u "$user" 2>/dev/null
          local droplim
          droplim=$(ps aux | grep dropbear | grep -v grep | grep -w "$user" | awk '{print $2}')
          [[ -n "$droplim" ]] && kill -9 $droplim 2>/dev/null

          # Bloquear la cuenta
          usermod -L "$user" 2>/dev/null

          # Registrar en lista de bloqueados (para auto-desbloqueo)
          if ! grep -qw "$user" "$unlock_file" 2>/dev/null; then
            echo "$user" >> "$unlock_file"
          fi

          # Log
          local fecha_hora
          fecha_hora="$(date '+%Y-%m-%d %H:%M:%S')"
          echo "[$fecha_hora] BLOQUEADO: $user (conexiones: $conexiones / límite: $limite)" >> "$LOG_FILE"
        fi
      fi
    done <<< "$(mostrar_usuarios)"

    # ── Auto-desbloqueo (si está configurado) ───────────
    if [[ "$ciclos_para_unlock" -gt 0 ]]; then
      ciclo_actual=$((ciclo_actual + 1))
      if [[ "$ciclo_actual" -ge "$ciclos_para_unlock" ]]; then
        desbloquear_usuarios
        ciclo_actual=0
      fi
    fi

    # Esperar el intervalo configurado
    sleep "$((intervalo_limit * 60))"
  done
}

# =========================================================
# PUNTO DE ENTRADA
# =========================================================
case "${1:-}" in
  --ssh)
    limitador_expirados
    ;;
  *)
    limitador_conexiones
    ;;
esac
