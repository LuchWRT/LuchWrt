#!/bin/sh
set -eu
umask 077
fail() { printf 'Luch VPN: %s\n' "$1" >&2; exit 1; }
[ "$(id -u)" = 0 ] || fail 'установку нужно запускать от имени root'
[ -r /etc/openwrt_release ] || fail 'не удалось определить OpenWrt'
. /etc/openwrt_release
case "$DISTRIB_RELEASE:$DISTRIB_ARCH" in
    21.02.7:x86_64) digest='cd9fa64dceacdd3cb9b87be1ac0ee07a7513c52a8f261816b24edc8c3115b7c3' ;;
    22.03.7:x86_64) digest='3274fbe4ecb69fc9ff9e12a5ce482faee895542b51233cf4c3894fab2a9072ff' ;;
    23.05.6:x86_64) digest='4101affef09352bfbe681cea76c2621411681aa04a1802e2c1eab86ead530e62' ;;
    24.10.8:x86_64) digest='6459917653031ee8d42b645955c639631f47647ba889896271f805c04860f4e4' ;;
    25.12.5:x86_64) digest='522eb8eff8444c1ef70d55ccdcd3a60bd6a87af9ef80d885c9b64fb6b842b7e7' ;;
    24.10.8:aarch64_generic) digest='212b680417a2c1c28ac68dec7c16df6b58d8d006a5f9ad5647cd1a92a91057c0' ;;
    24.10.8:arm_cortex-a15_neon-vfpv4) digest='12daae5500297d63a67442411ea5820d71fb0e61b7991c25893ddec35286fb82' ;;
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
