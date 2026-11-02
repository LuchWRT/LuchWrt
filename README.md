# LuchWrt

Клиент [Luch VPN](https://luch.one) для роутеров с OpenWrt. Подключает устройства домашней сети к VPN и управляется через SSH-меню на русском и английском языках.

**Текущий выпуск:** [v1.2.13](https://github.com/LuchWRT/LuchWrt/releases/tag/v1.2.13).

## Установка

Понадобятся подключение к интернету, SSH-доступ к роутеру от имени `root` и [подписка Luch VPN](https://t.me/LuchVPN_bot).

Подключитесь к роутеру по SSH. Скопируйте весь блок кнопкой копирования справа и вставьте в терминал. [Текст команды без форматирования](docs/install-command-v1.2.13.txt).

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
download_with_limit retry 3 curl --fail --location --max-time 60 --output "$download_file" "$download_url" >> "$log" 2>&1; }; u='https://raw.githubusercontent.com/LuchWRT/LuchWrt/9bbbfc78845544b2158773f7cedef235e875a9db/install-v1.2.13.sh'; download_https "$f" "$u" 256 || fail 'не удалось загрузить установщик по HTTPS';
ensure_checksum || fail 'не удалось подготовить SHA256 для проверки установщика'; actual=$(sha256sum "$f") || fail 'не удалось проверить установщик'; actual=${actual%% *};
[ "$actual" = 'b5777e95ab0c37eb13d576eb2c241ddfb159567c658afb4ac0d7d7ee70cd7fa2' ] || fail 'установщик не прошёл проверку целостности'; sh "$f"; )
```

Если команда не запускается или загрузка прервалась, см. [помощь с установкой](docs/INSTALLATION_HELP.md).

После установки меню откроется автоматически. Выберите язык, вставьте ссылку на подписку и выберите локацию. Для повторного открытия меню выполните `luch`.

## Возможности

- Выбор локации, проверка связи и управление подпиской из меню. Ручной выбор сохраняется: после перезагрузки клиент сначала подключается к нему, а при недоступности использует запасную локацию.
- Автоматическое обновление подписки и локаций.
- Сохранение маршрутизации, DNS и прямых подключений из конфигурации Xray.
- [Дополнительные GeoSite/GeoIP](docs/EXTRA_ROUTING.md): до 16 ссылок или DAT, DIRECT/VPN, обновление и удаление через **7 — Расширенные настройки**. Правила исходной конфигурации имеют приоритет.
- Переход на другую локацию при сбое. Если доступных локаций нет, клиент возвращает обычный выход в интернет через роутер.
- Проверка подписей и контрольных сумм обновлений с возможностью отката к предыдущей версии.

## Меню

Откройте меню командой `luch` и введите номер нужного пункта. Так выглядит русский интерфейс при включённом VPN:

```text
────────────────────────────────
Luch VPN  ·  OpenWrt

Управление подключением
  1  Статус
  2  Добавить или заменить подписку
  3  Сменить локацию
  4  Обновить локации и проверить VPN
  5  Проверить связь через VPN
  6  Отключить VPN
  7  Расширенные настройки

Программа и помощь
  8  Сведения о роутере
  9  Где получить подписку
 10  Проверить новую версию
 11  Установить новую версию
 12  Язык  [RU]
 13  Удалить Luch VPN

  0  Выход
Выберите номер:
```

После отключения VPN пункт **6** меняется на **«Включить VPN»**. Пункт **0** закрывает меню; текущее подключение сохраняется. Русский или английский язык можно выбрать в пункте **12**.

<details>
<summary><strong>7 — Расширенные настройки: GeoSite и GeoIP</strong></summary>

Здесь можно подключить базы доменов и IP-сетей по HTTPS-ссылке или из DAT-файла, выбрать категории и направить их напрямую (**DIRECT**) либо через VPN. Правила исходной конфигурации подписки имеют приоритет.

```text
Расширенные настройки · маршрутизация

  1  Добавить GeoSite (домены)
  2  Добавить GeoIP (IP-сети)
  3  Готовые профили сообщества
  4  Обновить все источники
  5  Включить / выключить дополнение
  6  Изменить категории или направление
  7  Удалить источник
  8  Изменить порядок источников
  0  Назад
  >
```

[Как подключить и настроить GeoSite/GeoIP](docs/EXTRA_ROUTING.md).

</details>

[Подробное описание пунктов и переходов](docs/MENU_GUIDE.md).

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

[Подробная совместимость, результаты испытаний и ограничения](docs/COMPATIBILITY_GUIDE.md). [Проверки v1.2.13](docs/release-v1.2.13-2026-11-03.md).

[Все выпуски](https://github.com/LuchWRT/LuchWrt/releases) · [Luch VPN](https://luch.one) · [Telegram](https://t.me/LuchVPN_bot) · [Веб-приложение](https://app.luch.one/webapp)
