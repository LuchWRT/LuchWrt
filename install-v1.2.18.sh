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
    17.01.7:x86_64) digest='0aa7d922fdd1d882b235ca039ae143784a9be27bc40421684e2df6dba155ceeb' ;;
    18.06.9:x86_64) digest='1191631c8a82a55f8a07bc3262d7b76ea0c1c4f3810f654769f41b2cbd614274' ;;
    19.07.10:x86_64) digest='a4b3ca86d71a0b73a3c6bfac5521e09663b4297938355ddeb105513d1615e03d' ;;
    21.02.7:x86_64) digest='a93ce0932f98c27c2dd31c3a6dc8bff2d23333aba405982dddb609c7e6bd517a' ;;
    22.03.7:aarch64_cortex-a53) digest='78fa13f07f5131a33bf1f0002569fc2330cb334100e5742a09e8e0ccd4cf6ac2' ;;
    22.03.7:x86_64) digest='58ffafed2a78f83c9d5d8065b1c3559886af8b52b5591e08808187b6f0cc92af' ;;
    23.05.6:aarch64_generic) digest='22301418868ce9b3c3c79a31d133f380165370ea4b915f848e2e3b772c8461cc' ;;
    23.05.6:arm_cortex-a15_neon-vfpv4) digest='170c1c06b9c48ba17a9f0d1c7700d97360ec7ca1976431da4c6935c673d65a57' ;;
    23.05.6:x86_64) digest='010d32b41676a49d4f3e534c217bf37af8ecbdfe4f076b543b6f1eb45ab51634' ;;
    24.10.8:aarch64_generic) digest='d6fa1c3ed1ab0c53b3a9a9bd10c75cee1ec0c493ea21412e1201727598240bea' ;;
    24.10.8:arm_cortex-a15_neon-vfpv4) digest='cc00aa8df7d265de73e76a55458a4ed01a192c2d9270874fbf3aecdd57f432f3' ;;
    24.10.8:i386_pentium4) digest='745bdf4ab0aa36798f5dbed4e8aded661a603047f1bcafea5de4f585371fa146' ;;
    24.10.8:x86_64) digest='c573326a70ed73396db92cb438867e9bab88abac65111693499341f60c211399' ;;
    25.12.4:aarch64_generic) digest='f68d4c353b5e9cf8fe22631cb2608ca70718750f003b8114eeca4a5c2dd504a3' ;;
    25.12.5:aarch64_generic) digest='561feabdbf7a4dad72b0f8844c7471c09d6f404fb6a81775c2992c4f3f60cc16' ;;
    25.12.5:arm_cortex-a15_neon-vfpv4) digest='d708ca47ceba88174b187cc8554f5051791a200a7f1dec621bc28724d5dfa025' ;;
    25.12.5:i386_pentium4) digest='415a918529d250d435f4b4760da2f9c1362a240bc989b59064492b4b361f2cc0' ;;
    25.12.5:x86_64) digest='e3683c2414b29b72fcfb7108c3810c2423e44ade09e214a262cdd008e9900bdb' ;;
    25.12.6:aarch64_generic) digest='c2f048ee0ebca44890465af87b53fd5372eba79b6045d370a47e7dcc004bc717' ;;
    25.12.6:x86_64) digest='70902e6798994a753cd09c03294dbe237adf46c2d817656613c691e6875bc49c' ;;
    *)
        case "$(uname -m):$arch" in
        i?86:i386*|i?86:386|i?86:x86|x86_64:i386*|x86_64:386|x86_64:x86) digest='4a47ac11f8f160cd2a674ef7224f035024070299fcdfec545af2980548617771' ;;
        x86_64:x86_64|x86_64:amd64) digest='c4e93222cfcfc2df2c8ed3d016974530be5f8f91bb39802e7bd05a638c43b39d' ;;
        aarch64:aarch64_*|aarch64:aarch64|aarch64:arm64) digest='02846bd4b39b5b39b6d91441d05f5c42c2c0529186b1fd6d987af5ae036945f6' ;;
        armv[5-8]*:arm_arm926*|armv[5-8]*:arm_xscale*|armv[5-8]*:arm_fa526*|armv[5-8]*:armv5) digest='3b581d498d6f5be7ac3c62ddb7e9c0bac35bea496ea75b6bf54dfb383c1a2f20' ;;
        armv[678]*:arm_arm1176*|armv[678]*:arm_mpcore*|armv[678]*:armv6) digest='261ca41d53e7a07b6cd310d5b84e519af0fafb1866b5f662826a4085a568e18b' ;;
        armv[78]*:arm_cortex-a*|armv[78]*:armv7) digest='ef39a89b58299f14f3d5a1ade0b058b268b4a8422c3cf9c1c81af550b078ac51' ;;
        mips*:mips_*|mips*:mips) digest='c136eb7d531b92f584e63eede343358a03c52619d4834bc1bfe4461b3cab2ce3' ;;
        mips*:mipsel_*|mips*:mipsle) digest='cda445b5078b24710696deb468776911d17b42184beeaef4a872ef3fa7e09453' ;;
        *) fail 'для процессора этого роутера пока нет подписанной сборки Luch' ;;
        esac ;;
esac
tmp=$(mktemp /tmp/luch-bootstrap.XXXXXX) || fail 'не удалось создать временный файл'
trap 'exit 1' 1 2 3 15
retry() { attempts=$1; shift; delay=2; while ! "$@"; do attempts=$((attempts - 1)); [ "$attempts" -gt 0 ] || return 1; sleep "$delay"; delay=$((delay * 2)); done; }
url='https://github.com/LuchWRT/LuchWrt/releases/download/v1.2.18/bootstrap-'$digest'.sh'
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
