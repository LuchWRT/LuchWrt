#!/bin/sh
set -eu
umask 077
fail() { printf 'Luch VPN: %s\n' "$1" >&2; exit 1; }
[ "$(id -u)" = 0 ] || fail 'установку нужно запускать от имени root'
[ -r /etc/openwrt_release ] || fail 'не удалось определить OpenWrt'
. /etc/openwrt_release
case "$DISTRIB_RELEASE:$DISTRIB_ARCH" in
    21.02.7:x86_64) digest='a04c8f23da1e102e8eb6ee4b0e7f38e927b893a0563215d54429f8e32c54b932' ;;
    22.03.7:x86_64) digest='a995bb1e03365ea43ab7f144c723afa78443b5e41b6218737a218ee901c7bff9' ;;
    23.05.6:x86_64) digest='24b4c2247eac95c5dfacc2b3b4d0c15b2278339eb52a9adfd924bdcbf969cc8c' ;;
    24.10.8:x86_64) digest='412901176fa7f6ed29d062629726a5a1c931aa9703c4c3f2fca6311e4084f6c8' ;;
    24.10.8:aarch64_generic) digest='5d094094fdd679e20d0205bc4d27b7bde4772df37238f95e361f37a13124fa14' ;;
    24.10.8:arm_cortex-a15_neon-vfpv4) digest='2a45e7b3831a6f3d50e292a59b22345ced2fa77ce13ecd204dbb6fcd10283ab8' ;;
    25.12.5:x86_64) digest='24470f97b6901cbd6aecbfc7ee5eacdeda5305baea957834eb84ee4d0eeb0a99' ;;
    *) fail 'для этой версии и архитектуры OpenWrt выпуск пока не испытан' ;;
esac
fetcher=wget
[ "$DISTRIB_RELEASE:$DISTRIB_ARCH" = '25.12.5:x86_64' ] && fetcher=curl
command -v sha256sum >/dev/null 2>&1 || fail 'нужна команда sha256sum'
tmp=$(mktemp /tmp/luch-bootstrap.XXXXXX) || fail 'не удалось создать временный файл'
cleanup() { rm -f "$tmp"; }
trap cleanup 0
trap 'exit 1' 1 2 3 15
url='https://github.com/LuchWRT/LuchWrt/releases/download/v1.2.4/bootstrap-'$digest'.sh'
if [ "$fetcher" = curl ]; then
    command -v apk >/dev/null 2>&1 || fail 'для этой прошивки нужен apk'
    if ! command -v curl >/dev/null 2>&1; then
        if ! apk update; then
            sleep 2
            apk update || fail 'не удалось обновить каталог системных пакетов'
        fi
        apk add curl || fail 'не удалось установить curl для загрузки выпуска'
    fi
    curl --fail --location --max-time 60 --output "$tmp" "$url" || fail 'не удалось загрузить установщик'
else
    command -v wget >/dev/null 2>&1 || fail 'нужен wget с проверкой HTTPS'
    wget -T 60 -q -O "$tmp" "$url" || fail 'не удалось загрузить установщик'
fi
actual=$(sha256sum "$tmp" | cut -d ' ' -f 1) || fail 'не удалось проверить установщик'
[ "$actual" = "$digest" ] || fail 'установщик не прошёл проверку целостности'
sh "$tmp"
