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
    17.01.7:x86_64) digest='1f7d97143683b6757fd389b954341a6fd000822648a04674e0b453cd5fc92a51' ;;
    18.06.9:x86_64) digest='a03603d22e6f6215548115714c972e2a1e9c791e89ca3ed87749882da67fbecc' ;;
    19.07.10:x86_64) digest='93849b8b90afb14e669e04b57458b64c671d6d088c97e695e5004fbc21999379' ;;
    21.02.7:x86_64) digest='908d79a25dc8ab7ec0e26f4cbaa0990d13caaa716b7e43de8bf7684c435aa851' ;;
    22.03.7:x86_64) digest='e567d02842860b859aa62a5802b878008d83fcd1fea80319e01ec7badaa8e80f' ;;
    22.03.7:aarch64_cortex-a53) digest='90f90dc2179e9bb45b0d55fd3ca395e0b08a71d78229b0a3b4aee56c53153afb' ;;
    23.05.6:x86_64) digest='a84c3fbb401efe598e0b3f8dc65b94fd15fe1501f5c1af7d97b50304fc772205' ;;
    23.05.6:aarch64_generic) digest='d01a5958fbc6696dbeb855aa7054785690bbc13fc7c18df914ebbff4b1e3dfd3' ;;
    23.05.6:arm_cortex-a15_neon-vfpv4) digest='92d7ec271ac732fece9e8febe20c8bfbc2980a9c472f5802e07448154d6d5418' ;;
    24.10.8:x86_64) digest='3cdb582d87d4c5c7805e2fd8d128443038b94bba7e303aeabaf28ee05f17bc74' ;;
    24.10.8:i386_pentium4) digest='a224ffd6d70ac0a4192649f6c595bf93a747708b01793a8efd73919ddb67873a' ;;
    24.10.8:aarch64_generic) digest='95ae159e21018baa7dbc9d08da91a7b80b4a63e8a58f07b94016e0e097a94e6f' ;;
    24.10.8:arm_cortex-a15_neon-vfpv4) digest='0dd02612f88ef10223877fe516da2aaa7440add74f87a5d3a328809c95bcc0c0' ;;
    25.12.5:x86_64) digest='79c0d0c220e4449316bd0ad1b84927f9fdfbeab053da4c54ccd598ac9e3e31c7' ;;
    25.12.5:aarch64_generic) digest='ef0b21eefc3c8d16db2420e07f58dc621c346ded909e76414fb57c5306b7c7af' ;;
    25.12.5:arm_cortex-a15_neon-vfpv4) digest='8fe06e2d3452aa65681cbab9da6cf10cbd35d0459235be79cf4b5fe37ed12c50' ;;
    25.12.5:i386_pentium4) digest='c9e98d80445fb2b128c1458c673f1b0eeecacb81d2a328af057a8b4d966eccd2' ;;
    *)
        case "$(uname -m):$arch" in
        x86_64:x86_64|x86_64:amd64) digest='b69e00f23a0c9e2ed18ebcdb6097cc88583316aad7b38be69d2d4d3224373f91' ;;
        aarch64:aarch64_*|aarch64:aarch64|aarch64:arm64) digest='da613d9a07e9d23781013b4dc2d76bf294e2a51916829f3799120defa1111164' ;;
        armv[78]*:arm_cortex-a*|armv[78]*:armv7) digest='4195ae8b46949909eb897119d028bf2296de2bda1ba4fea0644214f26716bf52' ;;
        armv[678]*:arm_arm1176*|armv[678]*:arm_mpcore*|armv[678]*:armv6) digest='1d821236c0290aa4b7f01b1b3f9b8d8f480aed5778442fd28beeb7016e8fffb4' ;;
        armv[5-8]*:arm_arm926*|armv[5-8]*:arm_xscale*|armv[5-8]*:arm_fa526*|armv[5-8]*:armv5) digest='01fd6395b655164393e1720f644fa024c5223c8212ad0944602a79fb99de4b8e' ;;
        i?86:i386*|i?86:386|i?86:x86|x86_64:i386*|x86_64:386|x86_64:x86) digest='e98c2eaf3b4d50a8fa72913607aa331da6a349b2c175091b150a1bfbcf8dd87b' ;;
        mips*:mips_*|mips*:mips) digest='c51e796f55b797deb4cc9af8e81ac739c5361b0e1395b10fb5b7a8e66994981c' ;;
        mips*:mipsel_*|mips*:mipsle) digest='c367db54f8f9fb69ac2469889ed9e36e374351d3eaecd441ac5bfe612869f9bf' ;;
        *) fail 'для процессора этого роутера пока нет подписанной сборки Luch' ;;
        esac ;;
esac
tmp=$(mktemp /tmp/luch-bootstrap.XXXXXX) || fail 'не удалось создать временный файл'
trap 'exit 1' 1 2 3 15
retry() { attempts=$1; shift; delay=2; while ! "$@"; do attempts=$((attempts - 1)); [ "$attempts" -gt 0 ] || return 1; sleep "$delay"; delay=$((delay * 2)); done; }
url='https://github.com/LuchWRT/LuchWrt/releases/download/v1.2.10/bootstrap-'$digest'.sh'
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
