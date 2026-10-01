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
    21.02.7:x86_64) digest='7eb91299fbd8c678f048373801ea5632846f9d699e873183bb43d5b25743fedc' ;;
    22.03.7:x86_64) digest='6a1124a5cd2ceb9b6ea625394019a3baca1135d9cb2a5d48fc3b434153567be1' ;;
    23.05.6:x86_64) digest='c6f79ae98a593c50cd283d0665cf547780595582bd9605ec8e3ea81deaf09985' ;;
    24.10.8:x86_64) digest='78c524ca1264dd06b14ef503c5b481c11c849b9e582d676bd6aec6e3f76d877f' ;;
    25.12.5:x86_64) digest='b34ebeeca92d77079a24af1a5a9d5ae504439b2b1dd9ff2666c362ec49233b63' ;;
    24.10.8:aarch64_generic) digest='b7acfbb95c71ca23bfae41d84d7717bb510d93439911b11da187f82f733782de' ;;
    24.10.8:arm_cortex-a15_neon-vfpv4) digest='233c7326b743bb43bcab08609743fdf26c0f2bcbd408b1f81eaef9f6e962685d' ;;
    *)
        case "$(uname -m):$DISTRIB_ARCH" in
        x86_64:x86_64) digest='2e715dacf4ff0bb0098e8582102c52eb65f66ca2f906e2e7ddf0742bd5d857b0' ;;
        aarch64:aarch64_*) digest='97033181392c0651092b959493a36980f8c16ddf254f3abd1eea6c2606412b1f' ;;
        armv7*:arm_cortex-a*) digest='b7cdebf02866c3c0899fd90c5ddec6b67f7f0d432e46fae825015ef3d685a0c0' ;;
        *) fail 'для процессора этого роутера пока нет подписанной сборки Luch' ;;
        esac ;;
esac
command -v sha256sum >/dev/null 2>&1 || fail 'нужна команда sha256sum'
tmp=$(mktemp /tmp/luch-bootstrap.XXXXXX) || fail 'не удалось создать временный файл'
trap 'exit 1' 1 2 3 15
retry() { attempts=$1; shift; delay=2; while ! "$@"; do attempts=$((attempts - 1)); [ "$attempts" -gt 0 ] || return 1; sleep "$delay"; delay=$((delay * 2)); done; }
url='https://github.com/LuchWRT/LuchWrt/releases/download/v1.2.7/bootstrap-'$digest'.sh'
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
