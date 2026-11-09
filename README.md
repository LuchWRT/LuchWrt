# LuchWrt

LuchWrt подключает устройства домашней сети к Luch VPN через роутер с OpenWrt. Подписку, локацию и маршрутизацию можно настроить на роутере в SSH-меню на русском или английском языке.

**Текущий выпуск** — [v1.2.18](https://github.com/LuchWRT/LuchWrt/releases/tag/v1.2.18).

## Установка

Понадобятся подключение к интернету, доступ к роутеру по SSH от имени `root` и подписка Luch VPN. [Оформить подписку в Telegram](https://t.me/LuchVPN_bot) или [открыть веб-приложение](https://app.luch.one/webapp).

Для первой установки нужно около **53 МиБ свободного места на ARM64** и **54–59 МиБ на других архитектурах**. Установщик рассчитывает требование для вашего роутера. Если вы используете внешний накопитель, сначала настройте на нём extroot OpenWrt, а затем выполните ту же команду. [Требования к памяти и настройка extroot](docs/STORAGE_AND_EXTROOT.md).

Подключитесь к роутеру по SSH и вставьте в терминал весь блок. [Команда в виде обычного текста](docs/install-command-v1.2.18.txt).

```sh
( set -eu; umask 077; f=''; log=''; fail() { printf 'Luch VPN: %s\n' "$1" >&2; if [ -n "${log:-}" ]; then printf 'Ошибка: %s\n' "$1" >> "$log"; fi; exit 1; }; retry() { attempts=$1; shift; delay=2; while ! "$@"; do attempts=$((attempts - 1)); [ "$attempts" -gt 0 ] || return 1; sleep "$delay"; delay=$((delay * 2)); done; };
trap 'result=$?; [ -z "$f" ] || rm -f "$f"; if [ -n "$log" ]; then if [ "$result" -ne 0 ]; then printf "Luch VPN: подробности ошибки: %s\n" "$log" >&2; else rm -f "$log"; fi; fi; exit "$result"' 0; trap 'exit 1' 1 2 3 15; [ "$(id -u)" = 0 ] || fail 'установку нужно запускать от имени root';
f=$(mktemp /tmp/luch-download.XXXXXX) || fail 'не удалось создать временный файл'; log=$(mktemp /tmp/luch-https.XXXXXX) || fail 'не удалось создать журнал загрузки'; ensure_checksum() { if command -v sha256sum >/dev/null 2>&1 && sha256sum /dev/null >> "$log" 2>&1; then return 0; fi;
if command -v busybox >/dev/null 2>&1 && busybox sha256sum /dev/null >> "$log" 2>&1; then sha256sum() { busybox sha256sum "$@"; }; return 0; fi; printf 'Luch VPN: устанавливаю SHA256 из системных пакетов...\n'; if command -v apk >/dev/null 2>&1; then
retry 3 apk update >> "$log" 2>&1 || printf 'Luch VPN: каталог пакетов обновлён не полностью; пробую доступные пакеты.\n'; retry 3 apk add coreutils-sha256sum >> "$log" 2>&1 || return 1; elif command -v opkg >/dev/null 2>&1; then
retry 3 opkg update >> "$log" 2>&1 || printf 'Luch VPN: каталог пакетов обновлён не полностью; пробую доступные пакеты.\n'; retry 3 opkg install coreutils-sha256sum >> "$log" 2>&1 || return 1; else printf 'не найден системный менеджер пакетов для установки SHA256\n' >> "$log"; return 1; fi;
if command -v sha256sum >/dev/null 2>&1 && sha256sum /dev/null >> "$log" 2>&1; then return 0; fi; printf 'после установки coreutils-sha256sum команда SHA256 недоступна или не работает\n' >> "$log"; return 1; }; download_with_limit() { if [ "$download_limit" -gt 0 ]; then (ulimit -f "$download_limit"; "$@"); else "$@"; fi; }; download_https() {
download_file=$1; download_url=$2; download_limit=${3:-0}; case "$download_limit" in ''|*[!0-9]*) return 1 ;; esac; if command -v curl >/dev/null 2>&1; then download_with_limit retry 3 curl --fail --location --max-time 60 --output "$download_file" "$download_url" >> "$log" 2>&1 && return 0; elif command -v wget >/dev/null 2>&1; then
download_with_limit retry 3 wget -T 60 -q -O "$download_file" "$download_url" >> "$log" 2>&1 && return 0; fi; printf 'Luch VPN: устанавливаю поддержку HTTPS из системных пакетов...\n'; if command -v apk >/dev/null 2>&1; then
retry 3 apk update >> "$log" 2>&1 || printf 'Luch VPN: каталог пакетов обновлён не полностью; пробую доступные пакеты.\n'; retry 3 apk add curl ca-certificates ca-bundle >> "$log" 2>&1 || return 1; elif command -v opkg >/dev/null 2>&1; then
retry 3 opkg update >> "$log" 2>&1 || printf 'Luch VPN: каталог пакетов обновлён не полностью; пробую доступные пакеты.\n'; retry 3 opkg install curl ca-certificates ca-bundle >> "$log" 2>&1 || return 1; else return 1; fi; command -v curl >/dev/null 2>&1 || return 1;
download_with_limit retry 3 curl --fail --location --max-time 60 --output "$download_file" "$download_url" >> "$log" 2>&1; }; u='https://raw.githubusercontent.com/LuchWRT/LuchWrt/9c1432daaadf6fed0879aeada33e33ddeede89f9/install-v1.2.18.sh'; download_https "$f" "$u" 256 || fail 'не удалось загрузить установщик по HTTPS';
ensure_checksum || fail 'не удалось подготовить SHA256 для проверки установщика'; actual=$(sha256sum "$f") || fail 'не удалось проверить установщик'; actual=${actual%% *};
[ "$actual" = 'd162a4bd5d8348977ac3049ce2a067f5c0bad1ccde2a50c28ca57087073e5204' ] || fail 'установщик не прошёл проверку целостности'; sh "$f"; )
```

Когда откроется меню, выберите язык, добавьте ссылку на подписку и выберите локацию. Если установка остановилась с ошибкой, откройте [инструкцию по устранению проблем](docs/INSTALLATION_HELP.md).

## Меню

Чтобы открыть меню, выполните `luch`. Введите номер нужного пункта.

| Что сделать | Пункт меню |
| --- | --- |
| Посмотреть состояние подключения | **1 — Статус** |
| Добавить или заменить подписку | **2 — Добавить или заменить подписку** |
| Выбрать другую локацию | **3 — Сменить локацию** |
| Проверить связь через VPN | **5 — Проверить связь через VPN** |
| Включить или отключить VPN | **6 — Включить VPN** или **Отключить VPN** |
| Настроить дополнительные правила | **7 — Расширенные настройки** |
| Сменить язык | **12 — Язык** |

Пункт **0 — Выход** закрывает меню и оставляет подключение в текущем состоянии. [Руководство по меню](docs/MENU_GUIDE.md).

## Подключение и маршрутизация

Клиент автоматически обновляет подписку и список локаций. Если выбранная локация недоступна, он пробует другие. Когда подключиться к VPN не удаётся, домашняя сеть возвращается к обычному выходу в интернет.

Через **Расширенные настройки** можно подключить GeoSite для доменов и GeoIP для IP-адресов и сетей. Выберите категории и задайте, как направлять их трафик — напрямую или через VPN. Правила из конфигурации подписки имеют приоритет. [Руководство по GeoSite и GeoIP](docs/EXTRA_ROUTING.md).

## Совместимость

Доступны сборки для x86-64, ARM64, ARMv7, ARMv6, ARMv5, 32-битного x86, MIPS и MIPSLE. Установщик подбирает пакет по версии OpenWrt и архитектуре процессора. Список сборок и проверенных конфигураций приведён в [таблице совместимости](docs/COMPATIBILITY_GUIDE.md).

## Обновление и удаление

Для обновления клиента выберите **11 — Установить новую версию** в меню или снова выполните команду установки из этого README. Установщик проверяет подпись пакета и сохраняет прежнюю версию для отката.

Пункт **13 — Удалить Luch VPN** удаляет клиент, его настройки и загруженные базы. Перед обновлением прошивки OpenWrt сохраните резервную копию настроек. [Резервное копирование и восстановление](docs/BACKUP_AND_SYSUPGRADE.md).

[Все выпуски и описания изменений](https://github.com/LuchWRT/LuchWrt/releases) · [Сайт Luch VPN](https://luch.one)
