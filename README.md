# LuchWrt

Клиент [Luch VPN](https://luch.one) для роутеров с OpenWrt. Подключает устройства домашней сети к VPN и управляется через SSH-меню на русском и английском языках.

**Текущий выпуск:** [v1.2.11](https://github.com/LuchWRT/LuchWrt/releases/tag/v1.2.11).

## Установка

Понадобятся подключение к интернету, SSH-доступ к роутеру от имени `root` и [подписка Luch VPN](https://t.me/LuchVPN_bot).

Подключитесь к роутеру по SSH и вставьте команду целиком:

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
download_with_limit retry 3 curl --fail --location --max-time 60 --output "$download_file" "$download_url" >> "$log" 2>&1; }; u='https://raw.githubusercontent.com/LuchWRT/LuchWrt/3027c7174bf447d1c8208eb8b54eb7b601572cb6/install-v1.2.11.sh'; download_https "$f" "$u" 256 || fail 'не удалось загрузить установщик по HTTPS';
ensure_checksum || fail 'не удалось подготовить SHA256 для проверки установщика'; actual=$(sha256sum "$f") || fail 'не удалось проверить установщик'; actual=${actual%% *};
[ "$actual" = 'caa95197ea2e227e8ca537782f391a10584126a11da31346dc71e7194a6bf17f' ] || fail 'установщик не прошёл проверку целостности'; sh "$f"; )
```

После установки меню откроется автоматически. Выберите язык, вставьте ссылку на подписку и выберите локацию. Для повторного открытия меню выполните `luch`.

## Возможности

- Выбор локации, проверка связи и управление подпиской из меню.
- Автоматическое обновление подписки и локаций.
- Сохранение маршрутизации, DNS и прямых подключений из конфигурации Xray.
- Переход на другую локацию при сбое. Если доступных локаций нет, клиент возвращает обычный выход в интернет через роутер.
- Проверка подписей и контрольных сумм обновлений с возможностью отката к предыдущей версии.

## Обновление и удаление

Для обновления выберите **«Установить новую версию»** в меню или повторите команду установки выше.

**«Отключить VPN»** возвращает обычный выход в интернет и сохраняет подписку. **«Удалить Luch VPN»** удаляет программу, её настройки и загруженные базы.

Перед обновлением самой OpenWrt сохраните [резервную копию настроек](docs/BACKUP_AND_SYSUPGRADE.md).

## Совместимость

Доступны сборки для x86-64, ARM64, ARMv7, ARMv6, ARMv5, 32-битного x86, MIPS и MIPSLE. Установщик автоматически выбирает точный пакет для версии OpenWrt и архитектуры:

| OpenWrt | Архитектуры точных пакетов |
| --- | --- |
| 17.01.7 | `x86_64` |
| 18.06.9 | `x86_64` |
| 19.07.10 | `x86_64` |
| 21.02.7 | `x86_64` |
| 22.03.7 | `x86_64`, `aarch64_cortex-a53` |
| 23.05.6 | `x86_64`, `aarch64_generic`, `arm_cortex-a15_neon-vfpv4` |
| 24.10.8 | `x86_64`, `i386_pentium4`, `aarch64_generic`, `arm_cortex-a15_neon-vfpv4` |
| 25.12.5 | `x86_64`, `aarch64_generic`, `arm_cortex-a15_neon-vfpv4`, `i386_pentium4` |

Если точного пакета нет, установщик выбирает подписанный универсальный пакет для семейства процессора и проверяет возможности системы.

Программа занимает около **42–50 МиБ** без системных зависимостей и обновляемых баз. Необходимый запас свободного места установщик проверяет перед установкой.

[Подробная совместимость, результаты испытаний и ограничения](docs/COMPATIBILITY_GUIDE.md).

[Все выпуски](https://github.com/LuchWRT/LuchWrt/releases) · [Luch VPN](https://luch.one) · [Telegram](https://t.me/LuchVPN_bot) · [Веб-приложение](https://app.luch.one/webapp)
