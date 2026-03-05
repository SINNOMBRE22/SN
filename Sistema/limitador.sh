#!/bin/bash
# =========================================================
# SinNombre v2.0 - Limitador de Cuentas SSH
# Archivo: Sistema/limitador.sh
#
# Uso:
#   Sistema/limitador.sh          → Limitador de conexiones (loop)
#   Sistema/limitador.sh --ssh    → Eliminar usuarios expirados (una vez)
# =========================================================

VPS_user="/etc/SN"
LOG_FILE="${VPS_user}/limit.log"

[[ ! -f "$LOG_FILE" ]] && touch "$LOG_FILE"

# ── Listar usuarios SSH del sistema ─────────────────────
mostrar_usuarios() {
  grep 'home' /etc/passwd | grep 'false' | grep -v 'syslog' | grep -v 'hwid' | grep -v 'token' | awk -F ':' '{print $1}'
}

# ── Contar conexiones activas de un usuario ──────────────
contar_conexiones() {
  local user="$1"
  local count=0

  local sshd_count
  sshd_count=$(ps -u "$user" 2>/dev/null | grep -c sshd || echo 0)
  count=$((count + sshd_count))

  local drop_count
  drop_count=$(ps aux 2>/dev/null | grep -i dropbear | grep -w "$user" | grep -v grep | wc -l)
  count=$((count + drop_count))

  if [[ -e /etc/openvpn/openvpn-status.log ]]; then
    local ovp_count
    ovp_count=$(grep -c ",$user," /etc/openvpn/openvpn-status.log 2>/dev/null || echo 0)
    count=$((count + ovp_count))
  fi

  echo "$count"
}

# ── Obtener límite de conexiones de un usuario ───────────
obtener_limite() {
  local user="$1"
  local limite
  limite=$(grep -w "$user" /etc/passwd | awk -F ':' '{print $5}' | cut -d ',' -f1)
  if [[ "$limite" =~ ^[0-9]+$ ]] && [[ "$limite" -gt 0 ]]; then
    echo "$limite"
  else
    echo "0"
  fi
}

# ── Matar procesos de un usuario ────────────────────────
matar_sesiones() {
  local user="$1"
  pkill -u "$user" 2>/dev/null
  local droplim
  droplim=$(ps aux | grep dropbear | grep -v grep | grep -w "$user" | awk '{print $2}')
  [[ -n "$droplim" ]] && kill -9 $droplim 2>/dev/null
}

# ── Desbloquear usuarios bloqueados por el limitador ────
desbloquear_usuarios() {
  local unlock_file="${VPS_user}/limitador_bloqueados.txt"
  [[ ! -f "$unlock_file" ]] && return

  while IFS= read -r user; do
    [[ -z "$user" ]] && continue
    if [[ "$(passwd --status "$user" 2>/dev/null | cut -d ' ' -f2)" = "L" ]]; then
      usermod -U "$user" 2>/dev/null
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] DESBLOQUEADO: $user (automático)" >> "$LOG_FILE"
    fi
  done < "$unlock_file"

  > "$unlock_file"
}

# =========================================================
# MODO 1: ELIMINAR USUARIOS EXPIRADOS (--ssh)
# =========================================================
limitador_expirados() {
  local fecha_actual
  fecha_actual=$(date +%s)

  while IFS= read -r user; do
    [[ -z "$user" ]] && continue

    local fecha_exp
    fecha_exp=$(chage -l "$user" 2>/dev/null | sed -n '4p' | awk -F ': ' '{print $2}')
    [[ "$fecha_exp" = @(never|nunca) ]] && continue
    [[ -z "$fecha_exp" ]] && continue

    local fecha_exp_sec
    fecha_exp_sec=$(date +%s --date="$fecha_exp" 2>/dev/null) || continue

    if [[ "$fecha_exp_sec" -lt "$fecha_actual" ]]; then
      matar_sesiones "$user"
      userdel --force "$user" 2>/dev/null
      sed -i "/$user/d" "${VPS_user}/passwd" 2>/dev/null
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] EXPIRADO ELIMINADO: $user (vencido: $fecha_exp)" >> "$LOG_FILE"
    fi
  done <<< "$(mostrar_usuarios)"

  exit 0
}

# =========================================================
# MODO 2: LIMITADOR DE CONEXIONES (loop infinito)
# =========================================================
limitador_conexiones() {
  local intervalo_limit intervalo_unlock
  local unlock_file="${VPS_user}/limitador_bloqueados.txt"

  if [[ -f "${VPS_user}/limit" ]]; then
    intervalo_limit=$(cat "${VPS_user}/limit" 2>/dev/null)
  else
    intervalo_limit=5
  fi

  if [[ -f "${VPS_user}/unlimit" ]]; then
    intervalo_unlock=$(cat "${VPS_user}/unlimit" 2>/dev/null)
  else
    intervalo_unlock=0
  fi

  [[ ! "$intervalo_limit" =~ ^[0-9]+$ ]] && intervalo_limit=5
  [[ ! "$intervalo_unlock" =~ ^[0-9]+$ ]] && intervalo_unlock=0

  local ciclos_para_unlock=0
  local ciclo_actual=0

  if [[ "$intervalo_unlock" -gt 0 && "$intervalo_limit" -gt 0 ]]; then
    ciclos_para_unlock=$(( intervalo_unlock / intervalo_limit ))
    [[ "$ciclos_para_unlock" -lt 1 ]] && ciclos_para_unlock=1
  fi

  [[ ! -f "$unlock_file" ]] && touch "$unlock_file"

  while true; do
    while IFS= read -r user; do
      [[ -z "$user" ]] && continue

      local limite conexiones
      limite=$(obtener_limite "$user")
      conexiones=$(contar_conexiones "$user")

      [[ "$limite" -eq 0 ]] && continue

      if [[ "$conexiones" -gt "$limite" ]]; then
        if [[ "$(passwd --status "$user" 2>/dev/null | cut -d ' ' -f2)" = "P" ]]; then
          matar_sesiones "$user"
          usermod -L "$user" 2>/dev/null

          if ! grep -qw "$user" "$unlock_file" 2>/dev/null; then
            echo "$user" >> "$unlock_file"
          fi

          echo "[$(date '+%Y-%m-%d %H:%M:%S')] BLOQUEADO: $user (conexiones: $conexiones / límite: $limite)" >> "$LOG_FILE"
        fi
      fi
    done <<< "$(mostrar_usuarios)"

    if [[ "$ciclos_para_unlock" -gt 0 ]]; then
      ciclo_actual=$((ciclo_actual + 1))
      if [[ "$ciclo_actual" -ge "$ciclos_para_unlock" ]]; then
        desbloquear_usuarios
        ciclo_actual=0
      fi
    fi

    sleep "$((intervalo_limit * 60))"
  done
}

# =========================================================
# PUNTO DE ENTRADA
# =========================================================
case "${1:-}" in
  --ssh) limitador_expirados ;;
  *)     limitador_conexiones ;;
esac
