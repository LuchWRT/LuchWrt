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
    17.01.7:x86_64) digest='0d2b85a197c7e9545d6db1a1547f5b89ff262558bbe5884e17f668c5bc4f774a' ;;
    18.06.9:x86_64) digest='3345c057c07077aac03e72e2c01125f46dbe8e14a8b0880ddcd6d7a021cf51de' ;;
    19.07.10:x86_64) digest='eb5430c3d1e073589cd2b2f6a7f48997d8a77f248c2a1c81b15a800ceb46684f' ;;
    21.02.7:x86_64) digest='b49d97e5cbcf6676db4a7f76a8f2448a3d1d202bfae865db5433b7247b743600' ;;
    22.03.7:x86_64) digest='f215699ea928fc0ae51f54d12b686b8b12a0cbae9d041de655f2b335dca28e9c' ;;
    22.03.7:aarch64_cortex-a53) digest='98e28ec46534a3abb624ed38ee4547a017ff5ea77a8007b1574b548e23356610' ;;
    23.05.6:x86_64) digest='a2fefedf47affb309188758ff59a55beef84b9bccbe581d32689786ea557e284' ;;
    23.05.6:aarch64_generic) digest='3d3eed96365f6723c562fd6d4d25530ae32046f9c15525dcebe43f2279f3cdc5' ;;
    23.05.6:arm_cortex-a15_neon-vfpv4) digest='f6aab2b1fa7d2c758a7b7ed7cd6bea2089783f44bba60becbeb12235d12fae4c' ;;
    24.10.8:x86_64) digest='5ea1a77f487fa4c5dd701faf9aba58eb21bb8d272599abff59eb6897afbc6d33' ;;
    24.10.8:i386_pentium4) digest='26e2eb86234b086e19c9b22b0efe205e637da256728a42ec5cc62b8698a3ceb2' ;;
    24.10.8:aarch64_generic) digest='a3938069de064a642778ba2f5c8633e0bca2c8f38e9ff1c643e35803d82a521a' ;;
    24.10.8:arm_cortex-a15_neon-vfpv4) digest='2aa75020676d25463ba4002be0f1545e56cc127aca308ae866ff08977ccd8615' ;;
    25.12.5:x86_64) digest='a12b667619bc3d724c9f6b48a8b3b95c26fdd63eb266327f6089beb4bb47600f' ;;
    25.12.5:aarch64_generic) digest='d9639a342a17edf8c1f98b7b46bb4eb0fedaf7d13434ba7683db9157a3ceb688' ;;
    25.12.5:arm_cortex-a15_neon-vfpv4) digest='29bd5a0c91619f084a8ce5dba7271502c4e3b6a73c519eba3c8d1acd06e092b9' ;;
    25.12.5:i386_pentium4) digest='4420734293b07841373a300bfc49f3fa71b1ae63bb758b07010c12f4d60c00b2' ;;
    *)
        case "$(uname -m):$arch" in
        x86_64:x86_64|x86_64:amd64) digest='9c25e1a023c2c42ebf9188da1d1c54799bc82e92c06d36a0b2f2686dd6ee54bb' ;;
        aarch64:aarch64_*|aarch64:aarch64|aarch64:arm64) digest='c12a6c08bc7653e4dcc558e41097ff12c86e778b4570313e4a2cdf893a62c71b' ;;
        armv[78]*:arm_cortex-a*|armv[78]*:armv7) digest='dee65bcab245f005b2a60c94264808a479da4c66f79c33af049e3806387fa2c2' ;;
        armv[678]*:arm_arm1176*|armv[678]*:arm_mpcore*|armv[678]*:armv6) digest='065e160c3e11b9d9da38e27f99df9dba9fa86d3329aef1eae8b2d1b2c92cfb0e' ;;
        armv[5-8]*:arm_arm926*|armv[5-8]*:arm_xscale*|armv[5-8]*:arm_fa526*|armv[5-8]*:armv5) digest='449a869bd1c0d9b18a936ce81386831ce2937f44b83d0ff0677c2ea5f4097dd9' ;;
        i?86:i386*|i?86:386|i?86:x86|x86_64:i386*|x86_64:386|x86_64:x86) digest='60377fbe29e571f22ca6585170e176046914fdb4bc7b9a95eb934e7b1f27ccae' ;;
        mips*:mips_*|mips*:mips) digest='abddca38d90b132642b643fb52fb2eabe18d0011237bdb928bf99d3e9f642d4c' ;;
        mips*:mipsel_*|mips*:mipsle) digest='96a87d9bc03f0a67b96b747336d17b22ef84806c88fcf90a26534ebda75ecfe0' ;;
        *) fail 'для процессора этого роутера пока нет подписанной сборки Luch' ;;
        esac ;;
esac
tmp=$(mktemp /tmp/luch-bootstrap.XXXXXX) || fail 'не удалось создать временный файл'
trap 'exit 1' 1 2 3 15
retry() { attempts=$1; shift; delay=2; while ! "$@"; do attempts=$((attempts - 1)); [ "$attempts" -gt 0 ] || return 1; sleep "$delay"; delay=$((delay * 2)); done; }
url='https://github.com/LuchWRT/LuchWrt/releases/download/v1.2.11/bootstrap-'$digest'.sh'
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
