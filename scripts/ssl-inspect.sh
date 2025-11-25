#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: ssl-inspect.sh [DOMAIN ...]

Без аргументов: выводит certbot certificates и certbot renew --dry-run.
С доменами: проверяет даты истечения и валидность через openssl.
USAGE
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -eq 0 ]]; then
  echo "[+] sudo certbot certificates"
  sudo certbot certificates
  echo
  echo "[+] sudo certbot renew --dry-run"
  sudo certbot renew --dry-run
  exit 0
fi

for domain in "$@"; do
  if [[ -z "$domain" ]]; then
    echo "[!] Пропущен домен" >&2
    continue
  fi

  echo "=== $domain ==="
  echo "[+] notBefore / notAfter"
  if ! echo | openssl s_client -connect "$domain":443 -servername "$domain" 2>/dev/null \
    | openssl x509 -noout -dates; then
    echo "[!] Не удалось получить сертификат для $domain" >&2
    continue
  fi

  echo "[+] Проверка истечения (checkend 0)"
  if echo | openssl s_client -connect "$domain":443 -servername "$domain" 2>/dev/null \
    | openssl x509 -checkend 0 -noout; then
    echo "✅ Сертификат действителен сейчас"
  else
    echo "❌ Сертификат уже истёк"
  fi
  echo
done
