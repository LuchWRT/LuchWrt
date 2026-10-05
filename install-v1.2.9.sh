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
    17.01.7:x86_64) digest='51f43132f77b4e6d942668b884b9d42df1dc8e2db0784ddd6ea2be0fb006e2d3' ;;
    18.06.9:x86_64) digest='4a1002db572e5db6e5ead920a23f833c697d12a5dde50aa798254a269f61c58f' ;;
    19.07.10:x86_64) digest='dcd14f0b25b29c86c90dfaa2cf351ddbbd2f2a79cc10e5efcb1d8cab1ea6ebb1' ;;
    21.02.7:x86_64) digest='4f90f48ebf93ffab98860e2b267e8fc36a9074ac379edccc52e6f23119586bc4' ;;
    22.03.7:x86_64) digest='e75ed2773dd2d4cb8f076109f4614566c00b4293fad5ec9f1e2ddb9a0f50d7b8' ;;
    22.03.7:aarch64_cortex-a53) digest='e9dfe0b3380f97eb28e6a1250fb0788863cf386159c22787d530528681246a6b' ;;
    23.05.6:x86_64) digest='4370e34011c4a9b454ae55b30de3d4343b8ff3be16f9708856f0cadfc9e74615' ;;
    23.05.6:aarch64_generic) digest='f9dc3e1cb8eec1caa09b6e268648959e67c7bc6695d2dd8c703fddce2d5b5bb9' ;;
    23.05.6:arm_cortex-a15_neon-vfpv4) digest='176b5d29f2caf745e2e747b7a3b629be55519375ec0e0a0b00e66e3b22a82c30' ;;
    24.10.8:x86_64) digest='ac16759fed3cc80984104eaa334b208a4edc5826cd82b7dcb48d140377dcc4af' ;;
    24.10.8:i386_pentium4) digest='e16af9324a94027e51f93bf37304a21e406865833a644c2e1b7a4c6265128320' ;;
    24.10.8:aarch64_generic) digest='2426ae4c22656ec9d1e055cb6998287013414dab23b4784978ea194b9c2b6c74' ;;
    24.10.8:arm_cortex-a15_neon-vfpv4) digest='2eeb3b54ab8b3b73fd14bb11996e4246a3fe890a00a60ec3ea0d23a5e1299ab2' ;;
    25.12.5:x86_64) digest='acd65bf25b1a16b2db582e29eff1674c4ceed61960160dcf451c5184c70fa25c' ;;
    25.12.5:aarch64_generic) digest='26682816ef60295f8a585744d2bdd6c6bf87dc13acb14bad7d7cc21235448baf' ;;
    25.12.5:arm_cortex-a15_neon-vfpv4) digest='7a31d3932fbad64527a7fdd67aaba241110fbae9dde662cd448dfd7f59f3c149' ;;
    25.12.5:i386_pentium4) digest='da4ede2d0225b5b1d45ac4ce771a34e7db4e39962c96fca1dcdecc6aa08729d2' ;;
    *)
        case "$(uname -m):$arch" in
        x86_64:x86_64|x86_64:amd64) digest='f0da84a34df2cdaa1185946844cea59ed4128e676863d02b139d706993f979ec' ;;
        aarch64:aarch64_*|aarch64:aarch64|aarch64:arm64) digest='2a9f8c32e47f5e23da718fc6785db901e56910973ef4536efe5f8733c3638d72' ;;
        armv[78]*:arm_cortex-a*|armv[78]*:armv7) digest='36aaa52462445a405b2cf4c2468213d32298a2b1f05b706046e03610ee9d2dd0' ;;
        armv[678]*:arm_arm1176*|armv[678]*:arm_mpcore*|armv[678]*:armv6) digest='e0efc0bce8c4957f5e9cd5f70a50d4cbb186975111a39f03c4fc71bfb95a3e70' ;;
        armv[5-8]*:arm_arm926*|armv[5-8]*:arm_xscale*|armv[5-8]*:arm_fa526*|armv[5-8]*:armv5) digest='547aa4cdb94e1c9d316f9839cdcff04a93f9a825ba93b7e0a5b21607f38ceab8' ;;
        i?86:i386*|i?86:386|i?86:x86|x86_64:i386*|x86_64:386|x86_64:x86) digest='ff8201388be0e2a9aa794dd90d390723f1d55f7c033f9379378735830f331a35' ;;
        mips*:mips_*|mips*:mips) digest='7db184e4ade2ceae300b5ffd9974eb61d64b99410f001eec1ed1653c883a0e4c' ;;
        mips*:mipsel_*|mips*:mipsle) digest='7f77f9f94d7474a45cb77565d9f53508b7abccd22d9827360b3b897a9fe22eb8' ;;
        *) fail 'для процессора этого роутера пока нет подписанной сборки Luch' ;;
        esac ;;
esac
tmp=$(mktemp /tmp/luch-bootstrap.XXXXXX) || fail 'не удалось создать временный файл'
trap 'exit 1' 1 2 3 15
retry() { attempts=$1; shift; delay=2; while ! "$@"; do attempts=$((attempts - 1)); [ "$attempts" -gt 0 ] || return 1; sleep "$delay"; delay=$((delay * 2)); done; }
url='https://github.com/LuchWRT/LuchWrt/releases/download/v1.2.9/bootstrap-'$digest'.sh'
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
