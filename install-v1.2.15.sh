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
    17.01.7:x86_64) digest='58f6884f0ecba678f112f05928c0fffb231493ebafa7c55ead1d3c5ac77db372' ;;
    18.06.9:x86_64) digest='3bbf3fad6e8fe66d68f68e42440a458705c12d741c89433bfd114c30477dfcb2' ;;
    19.07.10:x86_64) digest='c8adf321ec703089eaac2759eb051404a39da53982ef604c52e1758b86dcd643' ;;
    21.02.7:x86_64) digest='8dad438f52eeda46e6d02722f9538cc82a13a7c4219899bf05e133fb30ef263e' ;;
    22.03.7:aarch64_cortex-a53) digest='a8d839e63be9802d27ff38402a62d0a1a004583321599a2daf7a895e23b97d6a' ;;
    22.03.7:x86_64) digest='255ad91b392a09ec7cb0e461acfe6454415538f17d71dc2fe66695e3c1aa9748' ;;
    23.05.6:aarch64_generic) digest='2a2bfa4d049ea8c4e1a9f4d8acc55f875712f5a42b5eb4028d20d143338f658c' ;;
    23.05.6:arm_cortex-a15_neon-vfpv4) digest='f8514ce8cf1fb66019bdad70469a153b02cb8cc482f2d03cca125f9117e95432' ;;
    23.05.6:x86_64) digest='2f08330b5c71bfd3e9ff18357f219bff01f05e73a30467317dc4190838940700' ;;
    24.10.8:aarch64_generic) digest='df11b6d0c81fce2945abe56c0fc8a30090f88fa85afc6b8c90bcfbcf4b4d567f' ;;
    24.10.8:arm_cortex-a15_neon-vfpv4) digest='7727301a778cfc17516bb56f79abf01b1a5278f8cb6a62246f204666913114dc' ;;
    24.10.8:i386_pentium4) digest='72900674221a3f907d14de8c8f45b39826f407554034c0b7c99a01026778ba39' ;;
    24.10.8:x86_64) digest='6853f53433f89133475f55d973f715cd287bf95aa56ea6722ff4ad3fa3f554c3' ;;
    25.12.5:aarch64_generic) digest='0feb52a5801d8bf17f3a7f72ffe0c83ba1c3bcd692ad2a3aae42d7e4e7bb08b0' ;;
    25.12.5:arm_cortex-a15_neon-vfpv4) digest='0857c24333a8dbfa24db4037bf4494fbbf9417eebb21ed24a44424532a28245a' ;;
    25.12.5:i386_pentium4) digest='4bf267f973638f06fdb1c0bf80d35074e13d4f0d259898e162532235a939038f' ;;
    25.12.5:x86_64) digest='0c70f1457ae45810573afebf734371e4928abdd9c1b4a4f23f493750b7daeab0' ;;
    *)
        case "$(uname -m):$arch" in
        i?86:i386*|i?86:386|i?86:x86|x86_64:i386*|x86_64:386|x86_64:x86) digest='706ccc3ace7cb8fd0eecb7a1463072aa1dc2787ecaf4348361cdd52d11f7cce2' ;;
        x86_64:x86_64|x86_64:amd64) digest='b98facb170c04b87ac1abe20e1d8a230f32f6ab6a4f6e645b94876ff100234b1' ;;
        aarch64:aarch64_*|aarch64:aarch64|aarch64:arm64) digest='b218ef66fd29b9f1f3d1baf449398a0896ef63adb532ca360d942b5054a116a3' ;;
        armv[5-8]*:arm_arm926*|armv[5-8]*:arm_xscale*|armv[5-8]*:arm_fa526*|armv[5-8]*:armv5) digest='0b410062fa5e022710312afbe0863d793e1f6a893847a258018389e9f0c6b2d4' ;;
        armv[678]*:arm_arm1176*|armv[678]*:arm_mpcore*|armv[678]*:armv6) digest='5e1a8239283ebe4b0dfeccd696bf533b4c769c96e81e5eed558e003099654880' ;;
        armv[78]*:arm_cortex-a*|armv[78]*:armv7) digest='aa45088626ad316a84966f73b2fc333098c671f6b56aabdf0cba01ac486c37c1' ;;
        mips*:mips_*|mips*:mips) digest='2d72b50a586eb9ba52ac415054f7b10dddb457c5fbc4d587aa2008c502de091e' ;;
        mips*:mipsel_*|mips*:mipsle) digest='9bdacd156a05377d4de0ae80764571941d5bc7112f9c447bf15ed2e4f6755cff' ;;
        *) fail 'для процессора этого роутера пока нет подписанной сборки Luch' ;;
        esac ;;
esac
tmp=$(mktemp /tmp/luch-bootstrap.XXXXXX) || fail 'не удалось создать временный файл'
trap 'exit 1' 1 2 3 15
retry() { attempts=$1; shift; delay=2; while ! "$@"; do attempts=$((attempts - 1)); [ "$attempts" -gt 0 ] || return 1; sleep "$delay"; delay=$((delay * 2)); done; }
url='https://github.com/LuchWRT/LuchWrt/releases/download/v1.2.15/bootstrap-'$digest'.sh'
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
