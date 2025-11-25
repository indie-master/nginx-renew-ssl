#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)

ENV_FILES=("$SCRIPT_DIR/telegram.env" "/etc/letsencrypt/telegram.env")
for env_file in "${ENV_FILES[@]}"; do
  if [[ -f "$env_file" ]]; then
    # shellcheck disable=SC1090
    source "$env_file"
    break
  fi
done

if [[ -z "${TELEGRAM_BOT_TOKEN:-}" || -z "${TELEGRAM_CHAT_ID:-}" ]]; then
  exit 0
fi

CERT_DIR=${RENEWED_LINEAGE:-}
CERT_NAME=""
if [[ -n "$CERT_DIR" ]]; then
  CERT_NAME=$(basename "$CERT_DIR")
fi

EXPIRY_RAW=$(openssl x509 -in "${CERT_DIR}/fullchain.pem" -noout -enddate 2>/dev/null | cut -d= -f2)

domains=${RENEWED_DOMAINS:-}

message="✅ Certbot: сертификат \"${CERT_NAME}\" успешно обновлён."
if [[ -n "$domains" ]]; then
  message+=$'\n'"Домены: $domains"
fi
if [[ -n "$EXPIRY_RAW" ]]; then
  message+=$'\n'"Истекает: $EXPIRY_RAW"
fi

curl -sS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  -d chat_id="$TELEGRAM_CHAT_ID" \
  -d text="$message" \
  -d parse_mode="Markdown" >/dev/null
