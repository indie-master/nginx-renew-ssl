#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: ssl-renew-with-telegram.sh [PATH_TO_ENV]

Запускает certbot renew, логирует вывод и отправляет отчёт в Telegram.
По умолчанию использует /etc/letsencrypt/telegram.env.
USAGE
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -gt 1 ]]; then
  usage
  exit 1
fi

ENV_FILE=${1:-/etc/letsencrypt/telegram.env}

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

send_telegram() {
  local message=$1
  if [[ -z "${TELEGRAM_BOT_TOKEN:-}" || -z "${TELEGRAM_CHAT_ID:-}" ]]; then
    echo "[!] Переменные TELEGRAM_BOT_TOKEN и TELEGRAM_CHAT_ID не заданы, пропускаю отправку" >&2
    return 0
  fi

  curl -sS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d chat_id="$TELEGRAM_CHAT_ID" \
    -d text="$message" \
    -d parse_mode="Markdown" >/dev/null
}

LOG_FILE=$(mktemp)
trap 'rm -f "$LOG_FILE"' EXIT

echo "[+] Запуск sudo certbot renew"
if sudo certbot renew >"$LOG_FILE" 2>&1; then
  exit_code=0
else
  exit_code=$?
fi

log_tail=$(tail -n 20 "$LOG_FILE")
success_list=$(grep -E "^\s*The following certificates were successfully renewed:" -A 5 "$LOG_FILE" || true)

if [[ $exit_code -eq 0 ]]; then
  echo "[+] Certbot завершился успешно"
  msg="✅ Certbot: обновление сертификатов прошло успешно."
  if [[ -n "$success_list" ]]; then
    trimmed=$(echo "$success_list" | head -n 10)
    msg+=$'\n'"Подробнее:\n""$trimmed"
  else
    msg+=$'\n- Список сертификатов можно посмотреть командой:\n  sudo certbot certificates'
  fi
  send_telegram "$msg"
else
  echo "[!] Certbot завершился с ошибкой (код $exit_code)" >&2
  short_tail=$(echo "$log_tail" | tail -n 20)
  msg=$'❌ Certbot: ошибка при обновлении сертификатов.'
  msg+=$'\nПоследние строки лога:\n'"$short_tail"
  send_telegram "$msg"
fi

exit $exit_code
