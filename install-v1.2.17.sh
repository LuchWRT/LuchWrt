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
    if command -v apk >/dev/null 2>&1; then
        arch=$(apk --print-arch 2>> "${log:-/dev/null}") || fail 'не удалось узнать архитектуру пакетов через apk'
    elif command -v opkg >/dev/null 2>&1; then
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
    else
        fail 'не удалось определить архитектуру пакетов: нужны opkg или apk'
    fi
fi
[ "${#arch}" -le 64 ] || fail 'слишком длинная архитектура пакетов OpenWrt'
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
    17.01.7:x86_64) digest='12b5956c1bd7b5143582978e24b0d4155cd41784d2d1cf3a6a7848107d407912' ;;
    18.06.9:x86_64) digest='2620232d7586fbeab8730f02f4d44b20c857baf61783fa8dbd6962b87f73cfc0' ;;
    19.07.10:x86_64) digest='87e6e75a17ccb9b5babe57433da762f3f5cedccf1ffe6adedbe6301afa337f49' ;;
    21.02.7:x86_64) digest='bd9dcbcba389bca34fdd689153ee6b2f500ed1f2c0fb8d635beed37c16e453fc' ;;
    22.03.7:aarch64_cortex-a53) digest='31f4eb4fa26cf817266c7b6753fb94efe63b6b323fc78b9de6413d841eb9ae4f' ;;
    22.03.7:x86_64) digest='d9409132ce4bbf598d94274b5c886b0f545812c6fbde221ded1e24f6a1391683' ;;
    23.05.6:aarch64_generic) digest='1e7f5c56712f3702177836d740e58eee9036fb745574f7dc780545290fde23dd' ;;
    23.05.6:arm_cortex-a15_neon-vfpv4) digest='29c4eaa1151e496108b4f65ea5242eb4a9a03e5f0a7a081cb598a852fc71f61a' ;;
    23.05.6:x86_64) digest='ddecdfb7dd46165cc29c4529296ff3e5e52ae7b7a81e74127799b8fe2910da30' ;;
    24.10.8:aarch64_generic) digest='c0168ca691849c2cf86a4da9b35a82cc23c54db9dc0708c090c646df5fb75dd6' ;;
    24.10.8:arm_cortex-a15_neon-vfpv4) digest='f306310d0092309e062a0dd2a29fca83cd54d86bd67215c414a239a0e64573a5' ;;
    24.10.8:i386_pentium4) digest='69047a2a14d6bc5fe23a0c7a48f8dc8ee608f6b71eb1a191796d8db0ccf89a51' ;;
    24.10.8:x86_64) digest='acb9818dbfce2c2ea0b7a0185b5ddc8f110618f4ee533181e68446cfc1376195' ;;
    25.12.5:aarch64_generic) digest='a76d31ea46a979acc7a5c5c21a64b42f443fd1303919bf23d193c6f92c22c2fa' ;;
    25.12.5:arm_cortex-a15_neon-vfpv4) digest='1d9d965076a2cbd62ec49f8e5e3db62bfddd4bddb0b816bcee69168bec6c4122' ;;
    25.12.5:i386_pentium4) digest='c242285d2a20b8994e42a5f911a0a36a40474ceca4953ab1abd140fde186bcc6' ;;
    25.12.5:x86_64) digest='35166ac51d71f1d5ff4817f1b7dea35ed1597ad1cdc22cb97d40a9887dca5a3d' ;;
    25.12.6:aarch64_generic) digest='4754383742cea8c0bfa333d17176b0493ed480607c9f3da9ccb21b547806b7ec' ;;
    *)
        case "$(uname -m):$arch" in
        i?86:i386*|i?86:386|i?86:x86|x86_64:i386*|x86_64:386|x86_64:x86) digest='5528bc6372b7d09d46522f7cdea1675a50ff53ba159d6d1b87ea2daa6bbd53d7' ;;
        x86_64:x86_64|x86_64:amd64) digest='39316b9f29e95154fc36f967cd4fb3840ef07429996b3df3819d9cc1d79b983c' ;;
        aarch64:aarch64_*|aarch64:aarch64|aarch64:arm64) digest='93fbe44bb3913cc8c0151c57fc508d5632d8224e1079c46b5d56b42d0093af21' ;;
        armv[5-8]*:arm_arm926*|armv[5-8]*:arm_xscale*|armv[5-8]*:arm_fa526*|armv[5-8]*:armv5) digest='4c4c578f388274f81ef45098942f5a601df87099b4301d0e2570237cd9f77b33' ;;
        armv[678]*:arm_arm1176*|armv[678]*:arm_mpcore*|armv[678]*:armv6) digest='8d2be7def9f6200cba8c1d289440144a192aee3299a1c23a456b97b09690611b' ;;
        armv[78]*:arm_cortex-a*|armv[78]*:armv7) digest='4ee66ed500b9079f31a970e7d00561d0ae7f0894eafd6e04fc168fabe95b0f1a' ;;
        mips*:mips_*|mips*:mips) digest='685af58b5ca3043b0ad121006785e439c34f48846d2cd07750c6e888c6e71e1d' ;;
        mips*:mipsel_*|mips*:mipsle) digest='2249ec08b6327670ede69d3a9109963aca2797ad43b26d2b5f3882cdafdcddd3' ;;
        *) fail 'для процессора этого роутера пока нет подписанной сборки Luch' ;;
        esac ;;
esac
tmp=$(mktemp /tmp/luch-bootstrap.XXXXXX) || fail 'не удалось создать временный файл'
trap 'exit 1' 1 2 3 15
retry() { attempts=$1; shift; delay=2; while ! "$@"; do attempts=$((attempts - 1)); [ "$attempts" -gt 0 ] || return 1; sleep "$delay"; delay=$((delay * 2)); done; }
url='https://github.com/LuchWRT/LuchWrt/releases/download/v1.2.17/bootstrap-'$digest'.sh'
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
    if command -v apk >/dev/null 2>&1; then
        retry 3 apk update >> "$log" 2>&1 || printf 'Luch VPN: каталог пакетов обновлён не полностью; пробую доступные пакеты.\n'
        retry 3 apk add coreutils-sha256sum >> "$log" 2>&1 || return 1
    elif command -v opkg >/dev/null 2>&1; then
        retry 3 opkg update >> "$log" 2>&1 || printf 'Luch VPN: каталог пакетов обновлён не полностью; пробую доступные пакеты.\n'
        retry 3 opkg install coreutils-sha256sum >> "$log" 2>&1 || return 1
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
    if command -v apk >/dev/null 2>&1; then
        retry 3 apk update >> "$log" 2>&1 || printf 'Luch VPN: каталог пакетов обновлён не полностью; пробую доступные пакеты.\n'
        retry 3 apk add curl ca-certificates ca-bundle >> "$log" 2>&1 || return 1
    elif command -v opkg >/dev/null 2>&1; then
        retry 3 opkg update >> "$log" 2>&1 || printf 'Luch VPN: каталог пакетов обновлён не полностью; пробую доступные пакеты.\n'
        retry 3 opkg install curl ca-certificates ca-bundle >> "$log" 2>&1 || return 1
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
