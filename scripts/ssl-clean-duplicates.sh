#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: ssl-clean-duplicates.sh

Ищет линейки вида NAME-0001 и рекомендует удалить дубликаты, если домены совпадают.
USAGE
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -ne 0 ]]; then
  usage
  exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
  echo "[!] Требуется sudo для выполнения certbot" >&2
  exit 1
fi

CERT_OUTPUT=$(sudo certbot certificates 2>/dev/null || true)

if [[ -z "$CERT_OUTPUT" ]]; then
  echo "[!] Не удалось получить вывод certbot certificates" >&2
  exit 1
fi

declare -A DOMAINS_BY_NAME
current_name=""
while IFS= read -r line; do
  case "$line" in
    "Certificate Name:"*)
      current_name=${line#*: }
      ;;
    "Domains:"*)
      if [[ -n "$current_name" ]]; then
        domains_raw=${line#*: }
        domains_sorted=$(tr ' ' '\n' <<<"$domains_raw" | sort | tr '\n' ' ' | sed 's/[ ]*$//')
        DOMAINS_BY_NAME[$current_name]="$domains_sorted"
        current_name=""
      fi
      ;;
  esac
done <<< "$CERT_OUTPUT"

found=0
for name in "${!DOMAINS_BY_NAME[@]}"; do
  if [[ $name =~ ^(.+)-0[0-9]{3,}$ ]]; then
    base_name=${BASH_REMATCH[1]}
    base_domains=${DOMAINS_BY_NAME[$base_name]:-}
    dup_domains=${DOMAINS_BY_NAME[$name]}

    if [[ -n "$base_domains" && "$base_domains" == "$dup_domains" ]]; then
      ((found++))
      echo "Обнаружен дубликат сертификата:"
      echo "  Базовый: $base_name"
      echo "  Дубликат: $name"
      echo "  Домены: $dup_domains"
      echo
      echo "Рекомендуем удалить дубликат:" 
      echo "  sudo certbot delete --cert-name $name"
      echo
    fi
  fi
done

if [[ $found -eq 0 ]]; then
  echo "Дубликаты не обнаружены или домены не совпадают."
fi
