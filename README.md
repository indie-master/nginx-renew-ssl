# Let’s Encrypt + Nginx + Certbot: единая схема сертификатов и Telegram-оповещения

Этот репозиторий содержит набор bash-скриптов и инструкцию по работе с Let’s Encrypt, плагином nginx для Certbot и Telegram-уведомлениями. Цель — привести сертификаты к единой линейке для группы доменов, обеспечить автоматическое обновление и получать отчёты об успехах и ошибках.

## Требования

* ОС: Debian/Ubuntu с systemd и установленным nginx.
* Требуемые пакеты:

```bash
sudo apt update
sudo apt install nginx certbot python3-certbot-nginx curl
```

* Домены должны указывать на IP сервера и быть доступны по HTTP (порт 80).
* Если используется Cloudflare, на время настройки или диагностики переключайте домены, участвующие в http-01 проверке, в режим **DNS only** (серый облачко).

Все команды требуют права `root` или `sudo` и рассчитаны на опытных пользователей, знакомых с логами Nginx и Certbot.

## Базовые команды проверки

Просмотр установленных сертификатов:

```bash
sudo certbot certificates
```

Симуляция автообновления:

```bash
sudo certbot renew --dry-run
```

Проверка конкретного домена через `openssl`:

```bash
DOMAIN=example.com

echo | openssl s_client -connect $DOMAIN:443 -servername $DOMAIN 2>/dev/null \
  | openssl x509 -noout -dates
```

Быстрая проверка «истёк / не истёк»:

```bash
echo | openssl s_client -connect $DOMAIN:443 -servername $DOMAIN 2>/dev/null \
  | openssl x509 -checkend 0 -noout \
  && echo "✅ Сертификат действителен сейчас" \
  || echo "❌ Сертификат уже истёк"
```

## Одна линейка сертификата на группу доменов

`Certificate Name` в выводе `certbot certificates` задаёт имя линейки (директории `live/<name>`). Удобно держать одну линейку на группу доменов, например:

```
Certificate Name: example.com
Domains: example.com www.example.com api.example.com
```

Nginx при этом использует одну пару файлов:

```nginx
ssl_certificate     /etc/letsencrypt/live/example.com/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
```

Пример команды для создания или обновления линейки:

```bash
sudo certbot --nginx --cert-name example.com \
  -d example.com \
  -d www.example.com \
  -d api.example.com
```

## Пример Nginx-конфига для http-01

```nginx
server {
    listen 80;
    server_name example.com www.example.com api.example.com;

    return 301 https://$host$request_uri;
}
```

Certbot с плагином nginx временно добавляет свои `location` в этот `server`. Все домены, передаваемые через `-d`, должны присутствовать в одном из `server_name` на 80 порту.

## Чистка дубликатов сертификатов

При появлении `example.com` и `example.com-0001`:

1. Посмотрите список сертификатов:

```bash
sudo certbot certificates
```

2. Узнайте, какие линейки используются в Nginx:

```bash
grep -R "letsencrypt/live" -n /etc/nginx/sites-enabled
```

3. Приведите все `ssl_certificate` и `ssl_certificate_key` к одному имени линейки (например, `example.com`).
4. Удалите лишнюю линейку:

```bash
sudo certbot delete --cert-name example.com-0001
```

## Восстановление структуры live/archive

Если в `/etc/letsencrypt/live/` вместо symlink-ов оказались обычные файлы, используйте автоматизированный скрипт из `scripts/ssl-normalize-lineage.sh`, чтобы пересоздать линейку с корректными доменами через Certbot. Он повторно выпустит сертификат и восстановит нормальную структуру.

## Автообновление: systemd или cron

Проверьте таймер systemd:

```bash
systemctl status certbot.timer
```

Если таймер недоступен, можно использовать cron (рекомендуется обёртка `ssl-renew-with-telegram.sh`):

```bash
0 3 * * * root /path/to/scripts/ssl-renew-with-telegram.sh
```

## Уведомления в Telegram

В каталоге `examples/telegram-notify/` есть:

* `telegram.env.example` — пример файла с переменными окружения.
* `telegram-notify.sh` — hook для `renewal-hooks/post/`, срабатывает для каждого успешно обновлённого сертификата.
* `scripts/ssl-renew-with-telegram.sh` — обёртка для `certbot renew`, отправляет отчёт об успехе или ошибке.

Скрипты ожидают файл окружения, например `/etc/letsencrypt/telegram.env`:

```env
TELEGRAM_BOT_TOKEN=123456:ABCDEF
TELEGRAM_CHAT_ID=123456789
```

## Структура репозитория

```
.
├── README.md
├── scripts
│   ├── ssl-setup.sh
│   ├── ssl-inspect.sh
│   ├── ssl-normalize-lineage.sh
│   ├── ssl-clean-duplicates.sh
│   └── ssl-renew-with-telegram.sh
└── examples
    └── telegram-notify
        ├── telegram-notify.sh
        └── telegram.env.example
```

## Скрипты

Все скрипты написаны на `bash`, используют `#!/usr/bin/env bash`, проверяют аргументы и не содержат реальных доменов — только примеры (`example.com`, `api.example.com` и т.п.).

### scripts/ssl-setup.sh — интерактивная настройка

Запросит имя линейки и список доменов, покажет план и спросит подтверждение, затем выполнит:

```bash
sudo certbot --nginx --cert-name "$CERT_NAME" -d домен1 -d домен2 ...
```

По завершении выводит итог и рекомендует команды проверки (`certbot certificates`, `certbot renew --dry-run`).

### scripts/ssl-inspect.sh — инспекция состояния

* Без аргументов: выполняет `sudo certbot certificates` и `sudo certbot renew --dry-run`.
* С доменами в аргументах: для каждого домена показывает даты `notBefore` / `notAfter` и проверяет, истёк ли сертификат через `openssl -checkend 0`.

### scripts/ssl-normalize-lineage.sh — привести линейку к набору доменов

Использование:

```bash
scripts/ssl-normalize-lineage.sh CERT_NAME domain1 domain2 ...
```

Показывает план действий и обновляет линейку с помощью `certbot --nginx --cert-name`.

### scripts/ssl-clean-duplicates.sh — поиск и подсказки по дубликатам

Собирает вывод `sudo certbot certificates`, ищет линейки вида `NAME-0001`, сравнивает домены и рекомендует удалить дубликаты через `certbot delete`.

### scripts/ssl-renew-with-telegram.sh — обёртка для автообновления

Запускает `sudo certbot renew`, сохраняет лог и отправляет в Telegram отчёт:

* ✅ при успехе — краткая сводка и напоминание посмотреть `certbot certificates`.
* ❌ при ошибке — хвост лога (обрезанный, чтобы избежать длинных сообщений).

Скрипт подходит для `cron` и `systemd`.

### examples/telegram-notify/telegram-notify.sh — hook успешного обновления

Используется как `renewal-hooks/post` для отправки уведомлений после успешного обновления конкретного сертификата. Читает переменные Certbot (`RENEWED_LINEAGE`, `RENEWED_DOMAINS`), вытягивает дату окончания через `openssl` и отправляет краткое сообщение в Telegram.
