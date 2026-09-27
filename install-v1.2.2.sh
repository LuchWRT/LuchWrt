#!/bin/sh
set -eu
umask 077
fail() { printf 'Luch VPN: %s\n' "$1" >&2; exit 1; }
[ "$(id -u)" = 0 ] || fail 'установку нужно запускать от имени root'
[ -r /etc/openwrt_release ] || fail 'не удалось определить OpenWrt'
. /etc/openwrt_release
case "$DISTRIB_RELEASE:$DISTRIB_ARCH" in
    21.02.7:x86_64) digest='c531ba76880b0039fad4ace43c5a8cb4f54ee39227b7c2a47cab872fb1f10ed5' ;;
    22.03.7:x86_64) digest='879315ae5a1b6084df6b1077d7f848a2c139c93fa73ed29b2f3ff07b11473723' ;;
    23.05.6:x86_64) digest='f5c019cbbd5bdde39f62260f515b5fba83d1e762e34ae51a42da0bcc60402a2a' ;;
    24.10.8:x86_64) digest='02fe4ebadcdf75e3e90ee5cbb3f83c5a98014751484f200560bd9a2a5e301618' ;;
    25.12.5:x86_64) digest='fb40002a32b5e8faec5529b7c809dfe2ef497bcdda5ff6658a5887c454545936' ;;
    24.10.8:aarch64_generic) digest='5928501990f891b673fd5863bb6c56a079d282d305f21145feef83b9b08e721d' ;;
    24.10.8:arm_cortex-a15_neon-vfpv4) digest='35a1d6ad966c923c321f2e184a7815d3331f2717f58afc04067108ab4956d527' ;;
    *) fail 'для этой версии и архитектуры OpenWrt выпуск пока не испытан' ;;
esac
fetcher=wget
[ "$DISTRIB_RELEASE:$DISTRIB_ARCH" = '25.12.5:x86_64' ] && fetcher=curl
command -v sha256sum >/dev/null 2>&1 || fail 'нужна команда sha256sum'
tmp=$(mktemp /tmp/luch-bootstrap.XXXXXX) || fail 'не удалось создать временный файл'
cleanup() { rm -f "$tmp"; }
trap cleanup 0
trap 'exit 1' 1 2 3 15
url='https://github.com/LuchWRT/LuchWrt/releases/download/v1.2.2/bootstrap-'$digest'.sh'
if [ "$fetcher" = curl ]; then
    command -v apk >/dev/null 2>&1 || fail 'для этой прошивки нужен apk'
    if ! command -v curl >/dev/null 2>&1; then
        apk update || fail 'не удалось обновить каталог системных пакетов'
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
