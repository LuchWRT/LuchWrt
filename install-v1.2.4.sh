#!/bin/sh
set -eu
umask 077
fail() { printf 'Luch VPN: %s\n' "$1" >&2; exit 1; }
[ "$(id -u)" = 0 ] || fail 'установку нужно запускать от имени root'
[ -r /etc/openwrt_release ] || fail 'не удалось определить OpenWrt'
. /etc/openwrt_release
case "$DISTRIB_RELEASE:$DISTRIB_ARCH" in
    21.02.7:x86_64) digest='e89aee4cda52dc419bb8747191e5a1dd68ae2c2ff801ccf1679cdf008684df6b' ;;
    22.03.7:x86_64) digest='84071c670e819f9c3e28655b733e3aa5d426c2ab49f6fe9f2b765bd0f2264ac0' ;;
    23.05.6:x86_64) digest='f9f2379018380d2a0751ee27ffb10a6b079287e28aed32861a209de7df5f052d' ;;
    24.10.8:x86_64) digest='f345b4e3dac3b595b67a17c6fa04b47d9702085d968f4e5d43e1bc77298e673f' ;;
    25.12.5:x86_64) digest='34491ab77dd2783d3da0bf8279ca498dada42c2a5b6548a167166a8a8556d465' ;;
    24.10.8:aarch64_generic) digest='7dad881c15e878389674c033e5125475d8a98cfa20a6a64f9fdaee01146195b3' ;;
    24.10.8:arm_cortex-a15_neon-vfpv4) digest='445a64ca0ab4fed43ff60c3fd00b79b1c4555bc3b9912e21ac22f50be1e114eb' ;;
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
