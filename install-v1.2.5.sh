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
    21.02.7:x86_64) digest='f6283d79e3f1c515ef86c7a090668c7a40bb2b8fe797aa0cbb3397ad462f9f19' ;;
    22.03.7:x86_64) digest='fde43e404514949b2eebee3a28613cc781ad76a9e6467cc72bae29938874d9c2' ;;
    23.05.6:x86_64) digest='11afb56ef64962c304e2a02e9b439e63fab9aa8bbfb45c20bbc284ebd45a56b1' ;;
    24.10.8:x86_64) digest='7eaba7dc6b12947e762b25fe74e560fb5b2c659991ea00aba76ee0aac61c46c7' ;;
    25.12.5:x86_64) digest='b27895d34471fc99f5c4a2d210c01be47a0199ab1dc45b29147cb22943315898' ;;
    24.10.8:aarch64_generic) digest='b818ef2c9023b666bdf7ba6269dc271720922cf5c6cc9cc44aa558bbcfae6ddb' ;;
    24.10.8:arm_cortex-a15_neon-vfpv4) digest='8180d9e94cdd386e9cc7d11b9075221e8294619c3dd1efee150ce27699ba17b6' ;;
    *)
        case "$(uname -m):$DISTRIB_ARCH" in
        x86_64:x86_64) digest='04ad7ecaee05307125d789b47c466c78a044467ea0f22b118111f4133ff957b3' ;;
        aarch64:aarch64_*) digest='b40dc2897bdd191e3b863139606edb00fd95762a407af66ba68c04ec32d64b92' ;;
        armv7*:arm_cortex-a*) digest='da98acfedb855e34a103d506cd74c2fc8181255ba89c8d2d98f2f194993b8988' ;;
        *) fail 'для процессора этого роутера пока нет подписанной сборки Luch' ;;
        esac ;;
esac
command -v sha256sum >/dev/null 2>&1 || fail 'нужна команда sha256sum'
tmp=$(mktemp /tmp/luch-bootstrap.XXXXXX) || fail 'не удалось создать временный файл'
trap 'exit 1' 1 2 3 15
retry() { attempts=$1; shift; delay=2; while ! "$@"; do attempts=$((attempts - 1)); [ "$attempts" -gt 0 ] || return 1; sleep "$delay"; delay=$((delay * 2)); done; }
url='https://github.com/LuchWRT/LuchWrt/releases/download/v1.2.5/bootstrap-'$digest'.sh'
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
