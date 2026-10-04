# LuchWrt

**Простой клиент Xray/VLESS для OpenWrt от [Luch VPN](https://luch.one).** Подключение устройств домашней сети, выбор локации и обновление конфигураций — через понятное меню в SSH.

## Установка

Текущий выпуск — [v1.2.8](https://github.com/LuchWRT/LuchWrt/releases/tag/v1.2.8).

Подключитесь к роутеру по SSH от имени `root` и вставьте команду целиком — весь блок ниже:

```sh
( set -eu; umask 077; f=''; log=''; fail() { printf 'Luch VPN: %s\n' "$1" >&2; if [ -n "${log:-}" ]; then printf 'Ошибка: %s\n' "$1" >> "$log"; fi; exit 1; }; retry() { attempts=$1; shift; delay=2; while ! "$@"; do attempts=$((attempts - 1)); [ "$attempts" -gt 0 ] || return 1; sleep "$delay"; delay=$((delay * 2)); done; };
trap 'result=$?; [ -z "$f" ] || rm -f "$f"; if [ -n "$log" ]; then if [ "$result" -ne 0 ]; then printf "Luch VPN: подробности ошибки: %s\n" "$log" >&2; else rm -f "$log"; fi; fi; exit "$result"' 0; trap 'exit 1' 1 2 3 15; [ "$(id -u)" = 0 ] || fail 'установку нужно запускать от имени root';
f=$(mktemp /tmp/luch-download.XXXXXX) || fail 'не удалось создать временный файл'; log=$(mktemp /tmp/luch-https.XXXXXX) || fail 'не удалось создать журнал загрузки'; ensure_checksum() { if command -v sha256sum >/dev/null 2>&1 && sha256sum /dev/null >> "$log" 2>&1; then return 0; fi;
if command -v busybox >/dev/null 2>&1 && busybox sha256sum /dev/null >> "$log" 2>&1; then sha256sum() { busybox sha256sum "$@"; }; return 0; fi; printf 'Luch VPN: устанавливаю SHA256 из системных пакетов...\n'; if command -v opkg >/dev/null 2>&1; then
retry 3 opkg update >> "$log" 2>&1 || printf 'Luch VPN: каталог пакетов обновлён не полностью; пробую доступные пакеты.\n'; retry 3 opkg install coreutils-sha256sum >> "$log" 2>&1 || return 1; elif command -v apk >/dev/null 2>&1; then
retry 3 apk update >> "$log" 2>&1 || printf 'Luch VPN: каталог пакетов обновлён не полностью; пробую доступные пакеты.\n'; retry 3 apk add coreutils-sha256sum >> "$log" 2>&1 || return 1; else printf 'не найден системный менеджер пакетов для установки SHA256\n' >> "$log"; return 1; fi;
if command -v sha256sum >/dev/null 2>&1 && sha256sum /dev/null >> "$log" 2>&1; then return 0; fi; printf 'после установки coreutils-sha256sum команда SHA256 недоступна или не работает\n' >> "$log"; return 1; }; download_with_limit() { if [ "$download_limit" -gt 0 ]; then (ulimit -f "$download_limit"; "$@"); else "$@"; fi; }; download_https() {
download_file=$1; download_url=$2; download_limit=${3:-0}; case "$download_limit" in ''|*[!0-9]*) return 1 ;; esac; if command -v curl >/dev/null 2>&1; then download_with_limit retry 3 curl --fail --location --max-time 60 --output "$download_file" "$download_url" >> "$log" 2>&1 && return 0; elif command -v wget >/dev/null 2>&1; then
download_with_limit retry 3 wget -T 60 -q -O "$download_file" "$download_url" >> "$log" 2>&1 && return 0; fi; printf 'Luch VPN: устанавливаю поддержку HTTPS из системных пакетов...\n'; if command -v opkg >/dev/null 2>&1; then
retry 3 opkg update >> "$log" 2>&1 || printf 'Luch VPN: каталог пакетов обновлён не полностью; пробую доступные пакеты.\n'; retry 3 opkg install curl ca-certificates ca-bundle >> "$log" 2>&1 || return 1; elif command -v apk >/dev/null 2>&1; then
retry 3 apk update >> "$log" 2>&1 || printf 'Luch VPN: каталог пакетов обновлён не полностью; пробую доступные пакеты.\n'; retry 3 apk add curl ca-certificates ca-bundle >> "$log" 2>&1 || return 1; else return 1; fi; command -v curl >/dev/null 2>&1 || return 1;
download_with_limit retry 3 curl --fail --location --max-time 60 --output "$download_file" "$download_url" >> "$log" 2>&1; }; u='https://raw.githubusercontent.com/LuchWRT/LuchWrt/b1a7926391086da869fac6b72c7ef2d6620dc2ad/install-v1.2.8.sh'; download_https "$f" "$u" 256 || fail 'не удалось загрузить установщик по HTTPS';
ensure_checksum || fail 'не удалось подготовить SHA256 для проверки установщика'; actual=$(sha256sum "$f") || fail 'не удалось проверить установщик'; actual=${actual%% *};
[ "$actual" = 'd571e84f89d98046284efe99d9ae25a2b30799983a09a650834fbcad02fec7ea' ] || fail 'установщик не прошёл проверку целостности'; sh "$f"; )
```

После установки меню откроется само — выберите язык и добавьте подписку. Позднее меню можно открыть командой `luch`.

Программа занимает около **42–49 МиБ**. Дополнительно нужны системные пакеты и обновляемые базы маршрутизации; свободное место установщик проверит сам.

Установщик проверяет подпись и контрольные суммы файлов. При ошибке показывает причину и путь к временному журналу.

## Что умеет LuchWrt

- **Удобное управление:** добавление подписки, выбор локации, проверка связи и обновление из меню; понятный индикатор во время ожидания.
- **Полный Xray JSON:** сохраняет правила маршрутизации, DNS, прямые подключения и балансировку полученной конфигурации.
- **Автоматическое обновление локаций:** ежедневно в 2:00 по UTC+3; вручную — в любой момент.
- **Резервный переход:** при сбое выбранной локации проверяет следующие. Если ни одна не работает, снимает свои сетевые правила и возвращает обычный выход через роутер.
- **Проверяемые обновления:** сверяет подпись и контрольные суммы; предыдущая версия сохраняется для отката.
- **Русский и английский интерфейс:** язык выбирается при первом запуске и меняется в меню.
- **Ручное отключение:** один пункт меню возвращает обычный выход через роутер; там же VPN можно включить снова.
- **Полное удаление клиента:** отдельный пункт снимает сетевые правила и удаляет программу, подписку, настройки и загруженные базы.

## Меню

```text
Luch VPN  ·  OpenWrt
Управление подключением
  1  Статус
  2  Добавить или заменить подписку
  3  Сменить локацию
  4  Обновить локации и проверить VPN
  5  Проверить связь через VPN
  6  Отключить VPN
Программа и помощь
  7  Сведения о роутере
  8  Где получить подписку
  9  Проверить новую версию
 10  Установить новую версию
 11  Язык  [RU]
 12  Удалить Luch VPN
  0  Выход
Выберите номер:
```

Справка, статус, диагностика и результаты проверок открываются отдельным экраном. Введите `0`, чтобы вернуться в меню. При вводе подписки и выборе локации `0` возвращает назад без изменения настроек. Отключение VPN не удаляет подписку. После удаления программа покажет страницу с командой для повторной установки.

## Совместимость

Установщик поддерживает x86-64, ARM64, ARMv7, ARMv6, ARMv5, 32-битный x86, MIPS и MIPSLE. Для неиспытанного сочетания прошивки и архитектуры он выбирает универсальную подписанную сборку и проверяет возможности роутера. Отсутствие версии OpenWrt в таблице само по себе не блокирует установку.

Для каждой строки проверены установка из GitHub, меню, проверка конфигурации Xray и запуск службы Luch после перезагрузки в QEMU:

| OpenWrt | Архитектура пакетов | Испытанный выпуск |
| --- | --- | --- |
| 17.01.7 | `x86_64` | v1.2.8 |
| 18.06.9 | `x86_64` | v1.2.8 |
| 19.07.10 | `x86_64` | v1.2.8 |
| 21.02.7 | `x86_64` | v1.2.8 |
| 22.03.7 | `x86_64` | v1.2.8 |
| 23.05.6 | `x86_64` | v1.2.8 |
| 24.10.8 | `x86_64` | v1.2.8 |
| 24.10.8 | `i386_pentium4` | v1.2.8 |
| 24.10.8 | `aarch64_generic` | v1.2.8 |
| 24.10.8 | `arm_cortex-a15_neon-vfpv4` | v1.2.8 |
| 25.12.5 | `x86_64` | v1.2.8 |
| 25.12.5 | `aarch64_generic` | v1.2.8 |

OpenWrt 15.05.1 в эту таблицу не включён: на чистом образе штатные репозитории перенаправляют HTTPS-загрузку на отсутствующий OpenSSL, поэтому установщик безопасно останавливается до изменения системы. Это ограничение репозиториев старой прошивки, а не пропуск проверки подписи.

На OpenWrt 21.02.7 и 24.10.8 дополнительно проверена передача TCP, UDP и DNS через Xray с отдельного LAN-клиента, включая совместную работу с проверенными правилами PBR. Испытания в QEMU подтверждают указанные сценарии; особенности каждого физического роутера проверяются установщиком на месте.

[Все выпуски](https://github.com/LuchWRT/LuchWrt/releases) · [О Luch VPN](https://luch.one) · [Telegram](https://t.me/LuchVPN_bot) · [Веб-приложение](https://app.luch.one/webapp)
