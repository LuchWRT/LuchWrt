#!/bin/sh
set -eu
umask 077
fail() { printf 'Luch VPN: %s\n' "$1" >&2; exit 1; }
[ "$(id -u)" = 0 ] || fail 'установку нужно запускать от имени root'
[ -r /etc/openwrt_release ] || fail 'не удалось определить OpenWrt'
. /etc/openwrt_release
case "$DISTRIB_RELEASE:$DISTRIB_ARCH" in
    21.02.7:x86_64) digest='483b17a78af6764ab46a5352f3b0bb0719574d051e9122a08301738fce7ebd6b' ;;
    22.03.7:x86_64) digest='5e58bdc5b5e7d749bf8e02ab06fcfb93da3b441db7350b4047901e412b79c09b' ;;
    23.05.6:x86_64) digest='5292553a6765a450085f9bafb9d5d0c3629f44832a73865a7bc222b37f2d1659' ;;
    24.10.8:x86_64) digest='c335d9172072b064f988a70de1ca68169f1e242843d0c2c97a1797b1caa7a409' ;;
    25.12.5:x86_64) digest='32a21f50f84b32a119e20d96bf68f808bcc26fbcf2bff65788843bbaaf501800' ;;
    24.10.8:aarch64_generic) digest='06c12a1ee914a0e121d4e4e7c234d977763dbdd607780c44a353133d9d289568' ;;
    24.10.8:arm_cortex-a15_neon-vfpv4) digest='72ba22d0a1ed96e6de82df1260fdb1a428c7485ccddfaa8406af3e9c47bb1696' ;;
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
