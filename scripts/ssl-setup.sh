#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: ssl-setup.sh

Запустите без аргументов, чтобы интерактивно задать имя сертификата и список доменов.
USAGE
}

if [[ $# -ne 0 ]]; then
  usage
  exit 1
fi

echo "Введите имя линейки сертификата (например, example.com):"
read -r CERT_NAME

if [[ -z "$CERT_NAME" ]]; then
  echo "[!] Имя сертификата не может быть пустым" >&2
  exit 1
fi

echo "Введите список доменов через пробел (например: example.com www.example.com api.example.com):"
read -r DOMAINS_LINE

if [[ -z "$DOMAINS_LINE" ]]; then
  echo "[!] Список доменов не может быть пустым" >&2
  exit 1
fi

mapfile -t DOMAIN_ARRAY < <(tr ' ' '\n' <<<"$DOMAINS_LINE" | sed '/^$/d')

if [[ ${#DOMAIN_ARRAY[@]} -eq 0 ]]; then
  echo "[!] Не удалось разобрать домены" >&2
  exit 1
fi

echo "Будет создан/обновлён сертификат с именем: $CERT_NAME"
echo "Домены: ${DOMAIN_ARRAY[*]}"
echo "Используется плагин: nginx"

echo -n "Продолжить? (y/N): "
read -r CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "Отменено пользователем"
  exit 0
fi

CERTBOT_CMD=(sudo certbot --nginx --cert-name "$CERT_NAME")
for domain in "${DOMAIN_ARRAY[@]}"; do
  CERTBOT_CMD+=( -d "$domain" )
done

echo "[+] Запуск: ${CERTBOT_CMD[*]}"
if "${CERTBOT_CMD[@]}"; then
  echo "[+] Certbot завершился успешно"
else
  status=$?
  echo "[!] Certbot завершился с ошибкой (код $status)" >&2
  exit $status
fi

echo
echo "Для проверки используйте:" 
echo "  sudo certbot certificates"
echo "  sudo certbot renew --dry-run"
