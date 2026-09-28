#!/bin/sh
set -eu
umask 077
fail() { printf 'Luch VPN: %s\n' "$1" >&2; if [ -n "${log:-}" ]; then printf 'Ошибка: %s\n' "$1" >> "$log"; fi; exit 1; }
[ "$(id -u)" = 0 ] || fail 'установку нужно запускать от имени root'
[ -r /etc/openwrt_release ] || fail 'не удалось определить OpenWrt'
log=$(mktemp /tmp/luch-install.XXXXXX) || fail 'не удалось создать журнал установки'
tmp=''
cleanup() { [ -z "$tmp" ] || rm -f "$tmp"; }
trap 'status=$?; cleanup; if [ -n "$log" ]; then if [ "$status" -ne 0 ]; then printf "Luch VPN: подробности ошибки: %s\n" "$log" >&2; else rm -f "$log"; fi; fi; exit "$status"' 0
. /etc/openwrt_release
case "$DISTRIB_RELEASE:$DISTRIB_ARCH" in
    21.02.7:x86_64) digest='5043627783160b50f73b912dffdf371b83b1533ca64a7ec8289f7292b1106ba7' ;;
    22.03.7:x86_64) digest='bfe687ed05bb385e651b4e50dcd9bf51c944c975dab2e527929f5aaf9eb395c1' ;;
    23.05.6:x86_64) digest='d4365dea007ce7158c1fb73d59717c6fa2520f0e32b938b593241d373d88fee6' ;;
    24.10.8:x86_64) digest='9278971c7c2b5dc8c28df3348e1608c7c903dcc51e34470b6dc4df7b1d8efa26' ;;
    25.12.5:x86_64) digest='760c5d8beca24c35fbf1ed8e2c3c304197bf2654ef3a3d30f3ccba4c8cf1f099' ;;
    24.10.8:aarch64_generic) digest='6eecdf0ecd5afba51a68ad139bb39db02573b0804e9941598c470087e45e82f3' ;;
    24.10.8:arm_cortex-a15_neon-vfpv4) digest='d22d8769ce65da937132084afcf0ebe79ee58185aa8b38b8892f9dd06ce9a8cc' ;;
    *)
        case "$(uname -m):$DISTRIB_ARCH" in
        x86_64:x86_64) digest='d9e32944d908a175e9cf6893b8c76f525ad827a3899b7721f4c0f0a6bfca59d5' ;;
        aarch64:aarch64_*) digest='251b28e70573a11a130e8d3c3fe45b7fccbce2a09debbb3adc6763cdd34582d4' ;;
        armv7*:arm_cortex-a*) digest='be3aab0bbc9852ea4002e78330e0e98b59be1a9f53f1903fb4fab8f94f1c45a2' ;;
        *) fail 'для процессора этого роутера пока нет подписанной сборки Luch' ;;
        esac ;;
esac
command -v sha256sum >/dev/null 2>&1 || fail 'нужна команда sha256sum'
tmp=$(mktemp /tmp/luch-bootstrap.XXXXXX) || fail 'не удалось создать временный файл'
trap 'exit 1' 1 2 3 15
retry() { attempts=$1; shift; delay=2; while ! "$@"; do attempts=$((attempts - 1)); [ "$attempts" -gt 0 ] || return 1; sleep "$delay"; delay=$((delay * 2)); done; }
url='https://github.com/LuchWRT/LuchWrt/releases/download/v1.2.6/bootstrap-'$digest'.sh'
if command -v apk >/dev/null 2>&1; then
    if ! command -v curl >/dev/null 2>&1; then
        retry 3 apk update >> "$log" 2>&1 || fail 'не удалось обновить каталог системных пакетов'
        apk add curl >> "$log" 2>&1 || fail 'не удалось установить curl для загрузки выпуска'
    fi
fi
if command -v curl >/dev/null 2>&1; then
    retry 3 curl --fail --location --max-time 60 --output "$tmp" "$url" >> "$log" 2>&1 || fail 'не удалось загрузить установщик'
else
    command -v wget >/dev/null 2>&1 || fail 'нужен wget с проверкой HTTPS'
    retry 3 wget -T 60 -q -O "$tmp" "$url" >> "$log" 2>&1 || fail 'не удалось загрузить установщик'
fi
actual=$(sha256sum "$tmp" | cut -d ' ' -f 1) || fail 'не удалось проверить установщик'
[ "$actual" = "$digest" ] || fail 'установщик не прошёл проверку целостности'
rm -f "$log"
log=''
sh "$tmp"
