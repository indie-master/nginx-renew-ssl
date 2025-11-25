#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: ssl-normalize-lineage.sh CERT_NAME DOMAIN [DOMAIN...]

Приводит линейку CERT_NAME к указанным доменам через certbot --nginx.
USAGE
}

if [[ $# -lt 2 ]]; then
  usage
  exit 1
fi

CERT_NAME=$1
shift
DOMAINS=("$@")

echo "Будет обновлена линейка: $CERT_NAME"
echo "Домены: ${DOMAINS[*]}"
echo "Используется плагин: nginx"

echo -n "Продолжить? (y/N): "
read -r CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "Отменено пользователем"
  exit 0
fi

CERTBOT_CMD=(sudo certbot --nginx --cert-name "$CERT_NAME")
for domain in "${DOMAINS[@]}"; do
  CERTBOT_CMD+=( -d "$domain" )
done

echo "[+] Обновляю линейку ${CERT_NAME}"
if "${CERTBOT_CMD[@]}"; then
  echo "[+] Линейка успешно обновлена"
else
  status=$?
  echo "[!] Ошибка при обновлении линейки (код $status)" >&2
  exit $status
fi
