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
    17.01.7:x86_64) digest='a8f74be664c26f69fb97716b6e3f8f440970c4d1bb4e94a2eb2d7d14cf3091a9' ;;
    18.06.9:x86_64) digest='427ebfd44fcd8fe3e085bda1eefad3d49007aefe26f99cf6f9053f3a66ba8ef1' ;;
    19.07.10:x86_64) digest='c622fd84e32d7df7662e39fb3f62594f50a822dc9a7ddc2bf391fbd964447970' ;;
    21.02.7:x86_64) digest='13978675fcfdf56d5dcb7a5107757899569aed339c1dae0a8a5ad36c2ce540f6' ;;
    22.03.7:aarch64_cortex-a53) digest='eb599553e2271d5cd1a3d98055096e78e7339a1a16e54e289c480cd5ffb58679' ;;
    22.03.7:x86_64) digest='ccd460c2c29f6c9aca145f456e457a925b7e4415632500edce089b3ddf338186' ;;
    23.05.6:aarch64_generic) digest='f2a4ef71ee3ac6e4eed3b76fbab37e735dc6020ac6dc5ec025d1de3fd0d80983' ;;
    23.05.6:arm_cortex-a15_neon-vfpv4) digest='38a1d4b64c5b0ac65c9875844f0ace2c18ae1ca0a0da4d67ae5f814374c69996' ;;
    23.05.6:x86_64) digest='aa651210517d7d6a81763be3065da218570c8e57ee831287d9e83c7f6eb14bdd' ;;
    24.10.8:aarch64_generic) digest='355c24c22972bcf124a35c5c1c8a61046efc93708c9125b3f06cbb867d7e6af6' ;;
    24.10.8:arm_cortex-a15_neon-vfpv4) digest='ac69d3455a081a62e85226900c269beb1d1169cd45f27e89bceeb2680253ad5d' ;;
    24.10.8:i386_pentium4) digest='d3a31498999d8de2c54515f5afa9bdc9887a0b13e90ce9cc0d5f4e5f0b8d1f8f' ;;
    24.10.8:x86_64) digest='7ea2f7542119d704acde89599b36310c9d18dac20ef0e9d6fb96adc17e8a5cb7' ;;
    25.12.5:aarch64_generic) digest='207af8bbc59b79faee49dcf0a539b12ad386037bd30510aa54af242faaa1b12e' ;;
    25.12.5:arm_cortex-a15_neon-vfpv4) digest='734b925d3bac17ec87f996e5aed165ed9dbee714098fbdc920f20920d444002b' ;;
    25.12.5:i386_pentium4) digest='f0062499eb9045d8f05cc41c9bc3dab5975873327964c1cf82e3d9aba29596aa' ;;
    25.12.5:x86_64) digest='e5d0ccc14acd31f1284ab7694348825c74b73e4090c08974f9677296eef78982' ;;
    *)
        case "$(uname -m):$arch" in
        i?86:i386*|i?86:386|i?86:x86|x86_64:i386*|x86_64:386|x86_64:x86) digest='49cdc6f12d5d99035042d7092bdd0a2fbaca7c3df2b5da9fe6b98d3a5f0ccfff' ;;
        x86_64:x86_64|x86_64:amd64) digest='26ae60908162335af7aa09b6ab9a24e7c398ba49840a95db7e3db9600f442f13' ;;
        aarch64:aarch64_*|aarch64:aarch64|aarch64:arm64) digest='8a4a3659ba649ad6859c1d1ee3e3db894268d7d7a528af7fb49871492866120c' ;;
        armv[5-8]*:arm_arm926*|armv[5-8]*:arm_xscale*|armv[5-8]*:arm_fa526*|armv[5-8]*:armv5) digest='d26239d7a22d6c93ad3c1f581287d581415334052613ee99eae0359636aa8303' ;;
        armv[678]*:arm_arm1176*|armv[678]*:arm_mpcore*|armv[678]*:armv6) digest='dc840b62117c24413a8d2dd9295856c21e6996f9af9f4c6168b4df37ac375981' ;;
        armv[78]*:arm_cortex-a*|armv[78]*:armv7) digest='eb2804b1d6d42376eb38f023b3123afd30d5a61db1a8be1e626484ee0db5a613' ;;
        mips*:mips_*|mips*:mips) digest='9234f443805f135039df7cd70fc8d44b7f48d8888dbcc538403e29ca13b8abb0' ;;
        mips*:mipsel_*|mips*:mipsle) digest='7a044beb2ff87f984393e3f4a71d2cb57e1afa23868c2a1d6bf70203894d6f1b' ;;
        *) fail 'для процессора этого роутера пока нет подписанной сборки Luch' ;;
        esac ;;
esac
tmp=$(mktemp /tmp/luch-bootstrap.XXXXXX) || fail 'не удалось создать временный файл'
trap 'exit 1' 1 2 3 15
retry() { attempts=$1; shift; delay=2; while ! "$@"; do attempts=$((attempts - 1)); [ "$attempts" -gt 0 ] || return 1; sleep "$delay"; delay=$((delay * 2)); done; }
url='https://github.com/LuchWRT/LuchWrt/releases/download/v1.2.13/bootstrap-'$digest'.sh'
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
