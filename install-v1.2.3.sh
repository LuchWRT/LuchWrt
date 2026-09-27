#!/bin/sh
set -eu
umask 077
fail() { printf 'Luch VPN: %s\n' "$1" >&2; exit 1; }
[ "$(id -u)" = 0 ] || fail 'установку нужно запускать от имени root'
[ -r /etc/openwrt_release ] || fail 'не удалось определить OpenWrt'
. /etc/openwrt_release
case "$DISTRIB_RELEASE:$DISTRIB_ARCH" in
    21.02.7:x86_64) digest='32540ff5b83dc946daa09ebc0e19dbbbe42061b495d4d5182dbdf53fb7b69262' ;;
    22.03.7:x86_64) digest='9a98bd6e22a977404ad4842ecd427693c81bcb08461967c761785f8a2a313e7a' ;;
    23.05.6:x86_64) digest='44113b217e7804dc1efe23c269bbf31bc8a3aae312938ab2eee0534b7850036c' ;;
    24.10.8:x86_64) digest='ae9af8fd4000cb684a07752e26b051797708f2ec61209de7cd0f589b306649ca' ;;
    25.12.5:x86_64) digest='8b7479ad453a5630f72f9820f4752e07e8b59b868881a763986a165d31e93363' ;;
    24.10.8:aarch64_generic) digest='3ebba2fd5610bfc964872f9af1258d284b55ecea8a6de94ec46533dc0dbe81e0' ;;
    24.10.8:arm_cortex-a15_neon-vfpv4) digest='a9427fcfc90844dd4dcc5897269f7e74c344335e483d9a8b9b7549c7b38f6acf' ;;
    *) fail 'для этой версии и архитектуры OpenWrt выпуск пока не испытан' ;;
esac
fetcher=wget
[ "$DISTRIB_RELEASE:$DISTRIB_ARCH" = '25.12.5:x86_64' ] && fetcher=curl
command -v sha256sum >/dev/null 2>&1 || fail 'нужна команда sha256sum'
tmp=$(mktemp /tmp/luch-bootstrap.XXXXXX) || fail 'не удалось создать временный файл'
cleanup() { rm -f "$tmp"; }
trap cleanup 0
trap 'exit 1' 1 2 3 15
url='https://github.com/LuchWRT/LuchWrt/releases/download/v1.2.3/bootstrap-'$digest'.sh'
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
