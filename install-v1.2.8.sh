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
release=''
arch=''
while IFS='=' read -r field value; do
    case "$field" in DISTRIB_RELEASE) release=$value ;; DISTRIB_ARCH) arch=$value ;; esac
done < /etc/openwrt_release
release=${release#\'}; release=${release%\'}; release=${release#\"}; release=${release%\"}
arch=${arch#\'}; arch=${arch%\'}; arch=${arch#\"}; arch=${arch%\"}
[ -n "$release" ] || fail 'не удалось определить версию OpenWrt'
# Read the package ABI when old OpenWrt images omit DISTRIB_ARCH. Never
# derive package names from uname alone: endian and ARM ABI must agree.
if [ -z "$arch" ]; then
    if command -v opkg >/dev/null 2>&1; then
        arch_output=$(opkg print-architecture 2>> "${log:-/dev/null}") || fail 'не удалось узнать архитектуру пакетов через opkg'
        arch=$(printf '%s\n' "$arch_output" | awk '
            BEGIN { priority=-2147483649 }
            NF == 0 { next }
            NF != 3 || $1 != "arch" || $3 !~ /^-?[0-9]+$/ || $3+0 < -2147483648 || $3+0 > 2147483647 { invalid=1; next }
            $2 == "all" || $2 == "noarch" { next }
            $2 !~ /^[A-Za-z0-9][A-Za-z0-9._+-]*$/ || length($2) > 64 { invalid=1; next }
            $3+0 > priority { priority=$3+0; selected=$2; ambiguous=0; next }
            $3+0 == priority && selected != $2 { ambiguous=1 }
            END { if (invalid || ambiguous || selected == "") exit 1; print selected }
        ') || fail 'opkg сообщил неоднозначную или некорректную архитектуру пакетов'
    elif command -v apk >/dev/null 2>&1; then
        arch=$(apk --print-arch 2>> "${log:-/dev/null}") || fail 'не удалось узнать архитектуру пакетов через apk'
    else
        fail 'не удалось определить архитектуру пакетов: нужны opkg или apk'
    fi
fi
case "$arch" in
    ''|all|noarch|*[!A-Za-z0-9._+-]*) fail 'некорректная архитектура пакетов OpenWrt' ;;
esac
case "$(uname -m):$arch" in
    x86_64:x86_64|x86_64:amd64|i?86:i386*|i?86:386|i?86:x86|x86_64:i386*|x86_64:386|x86_64:x86) ;;
    aarch64:aarch64|aarch64:aarch64_*|aarch64:arm64) ;;
    armv[78]*:arm_cortex-a*|armv[78]*:armv7|armv[678]*:arm_arm1176*|armv[678]*:arm_mpcore*|armv[678]*:armv6|armv[5-8]*:arm_arm926*|armv[5-8]*:arm_xscale*|armv[5-8]*:arm_fa526*|armv[5-8]*:armv5) ;;
    mips*:mips_*|mips*:mipsel_*|mips*:mips|mips*:mipsle) ;;
    *) fail 'архитектура пакетов не соответствует процессору или для неё нет сборки Luch' ;;
esac

case "$release:$arch" in
    21.02.7:x86_64) digest='b9b43561f5b4de6353e3a086252a1352c1e26a1b7a870fad6d3b2081ad80f6c6' ;;
    22.03.7:x86_64) digest='31e00cc67f50eb9d252fb83be529ca6714498b4feaec639ad762cfd8f59f2030' ;;
    23.05.6:x86_64) digest='6950fcb9c19eb279a8d77a4716e2af0d20330c62e343e006a1824b2653d046e9' ;;
    24.10.8:x86_64) digest='fc539ed1789f0cecce629d99fcc391c5f98d07def4bab8c9ecd54205ccc51c25' ;;
    25.12.5:x86_64) digest='4031a0f951afdd06b935069a063f2abe2941b881f66e3a1e3d2f71d8e3619f89' ;;
    24.10.8:aarch64_generic) digest='872634324d013152b86763f247bd7ca8b9e446922640b12f7314bc44f284fc04' ;;
    24.10.8:arm_cortex-a15_neon-vfpv4) digest='18f91fd960bf3abb2d51009206044e793634ebf86905c91726fde3578e66606a' ;;
    25.12.5:aarch64_generic) digest='60ed95cb9355475c5c8b5a0f19d44f24940e209fdf90b019d1ce0974eb450bc5' ;;
    *)
        case "$(uname -m):$arch" in
        x86_64:x86_64|x86_64:amd64) digest='8b27da4879e40c71195e236e4f2adeec24fbf898e96c625f10446ca65801140d' ;;
        aarch64:aarch64_*|aarch64:aarch64|aarch64:arm64) digest='e47ebb617d6bb3e7b7df5d1cb3797572bc6666e183f33f7c593c05d6e8ff3adf' ;;
        armv[78]*:arm_cortex-a*|armv[78]*:armv7) digest='1e509d751025e802ce5adbd26f22a9646400e9981b26e1f5cbaf892c6d64b90c' ;;
        armv[678]*:arm_arm1176*|armv[678]*:arm_mpcore*|armv[678]*:armv6) digest='f27873877859796d193203ad501f3f91c00e0321ddba570f24d243c0ae812c8d' ;;
        armv[5-8]*:arm_arm926*|armv[5-8]*:arm_xscale*|armv[5-8]*:arm_fa526*|armv[5-8]*:armv5) digest='9708435cab937b78e069d270096ffe88ffe273f760ebc780c734af0df3e084f4' ;;
        i?86:i386*|i?86:386|i?86:x86|x86_64:i386*|x86_64:386|x86_64:x86) digest='c11857a7d139c156c8f5a30fa263fae7e1b423a0af6ad78502867b18b97c693c' ;;
        mips*:mips_*|mips*:mips) digest='69e7db8fbfabbd8ee011e569c82c8fedd3ceb04a3843244751b3e09babc892d9' ;;
        mips*:mipsel_*|mips*:mipsle) digest='50f14cefb2db92161cccb0bc81a606677784867146644c29cef624e263dfedf2' ;;
        *) fail 'для процессора этого роутера пока нет подписанной сборки Luch' ;;
        esac ;;
esac
tmp=$(mktemp /tmp/luch-bootstrap.XXXXXX) || fail 'не удалось создать временный файл'
trap 'exit 1' 1 2 3 15
retry() { attempts=$1; shift; delay=2; while ! "$@"; do attempts=$((attempts - 1)); [ "$attempts" -gt 0 ] || return 1; sleep "$delay"; delay=$((delay * 2)); done; }
url='https://github.com/LuchWRT/LuchWrt/releases/download/v1.2.8/bootstrap-'$digest'.sh'
# Download through verified HTTPS. Old OpenWrt wget may have no SSL support;
# install HTTPS support through the existing system feeds and signature policy.
# No feed URLs, trust keys or signature settings are changed here.
ensure_checksum() {
    if command -v sha256sum >/dev/null 2>&1 && sha256sum /dev/null >> "$log" 2>&1; then
        return 0
    fi
    if command -v busybox >/dev/null 2>&1 && busybox sha256sum /dev/null >> "$log" 2>&1; then
        sha256sum() { busybox sha256sum "$@"; }
        return 0
    fi
    printf 'Luch VPN: устанавливаю SHA256 из системных пакетов...\n'
    if command -v opkg >/dev/null 2>&1; then
        retry 3 opkg update >> "$log" 2>&1 || printf 'Luch VPN: каталог пакетов обновлён не полностью; пробую доступные пакеты.\n'
        retry 3 opkg install coreutils-sha256sum >> "$log" 2>&1 || return 1
    elif command -v apk >/dev/null 2>&1; then
        retry 3 apk update >> "$log" 2>&1 || printf 'Luch VPN: каталог пакетов обновлён не полностью; пробую доступные пакеты.\n'
        retry 3 apk add coreutils-sha256sum >> "$log" 2>&1 || return 1
    else
        printf 'не найден системный менеджер пакетов для установки SHA256\n' >> "$log"
        return 1
    fi
    if command -v sha256sum >/dev/null 2>&1 && sha256sum /dev/null >> "$log" 2>&1; then
        return 0
    fi
    printf 'после установки coreutils-sha256sum команда SHA256 недоступна или не работает\n' >> "$log"
    return 1
}
download_with_limit() {
    if [ "$download_limit" -gt 0 ]; then
        (ulimit -f "$download_limit"; "$@")
    else
        "$@"
    fi
}
download_https() {
    download_file=$1
    download_url=$2
    download_limit=${3:-0}
    case "$download_limit" in ''|*[!0-9]*) return 1 ;; esac
    if command -v curl >/dev/null 2>&1; then
        download_with_limit retry 3 curl --fail --location --max-time 60 --output "$download_file" "$download_url" >> "$log" 2>&1 && return 0
    elif command -v wget >/dev/null 2>&1; then
        download_with_limit retry 3 wget -T 60 -q -O "$download_file" "$download_url" >> "$log" 2>&1 && return 0
    fi
    printf 'Luch VPN: устанавливаю поддержку HTTPS из системных пакетов...\n'
    if command -v opkg >/dev/null 2>&1; then
        retry 3 opkg update >> "$log" 2>&1 || printf 'Luch VPN: каталог пакетов обновлён не полностью; пробую доступные пакеты.\n'
        retry 3 opkg install curl ca-certificates ca-bundle >> "$log" 2>&1 || return 1
    elif command -v apk >/dev/null 2>&1; then
        retry 3 apk update >> "$log" 2>&1 || printf 'Luch VPN: каталог пакетов обновлён не полностью; пробую доступные пакеты.\n'
        retry 3 apk add curl ca-certificates ca-bundle >> "$log" 2>&1 || return 1
    else
        return 1
    fi
    command -v curl >/dev/null 2>&1 || return 1
    download_with_limit retry 3 curl --fail --location --max-time 60 --output "$download_file" "$download_url" >> "$log" 2>&1
}

download_https "$tmp" "$url" 256 || fail 'не удалось загрузить установщик по HTTPS'
ensure_checksum || fail 'не удалось установить средство проверки SHA-256'
actual=$(sha256sum "$tmp") || fail 'не удалось проверить установщик'
actual=${actual%% *}
[ "$actual" = "$digest" ] || fail 'установщик не прошёл проверку целостности'
rm -f "$log"
log=''
sh "$tmp"
