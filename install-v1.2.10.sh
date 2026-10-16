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
    17.01.7:x86_64) digest='54424714f74f1ecf9daffa1a33c4b83dd4f2aaa912839cf6d34c98919b34fba7' ;;
    18.06.9:x86_64) digest='e92d64262fba2b27e73f80c9ba36f6955a5fa5ec11b12b784bbf31e7d7d50cd4' ;;
    19.07.10:x86_64) digest='c14280c62a3c7685a5df082444892b4defef166561984964bb0281eb6eff6771' ;;
    21.02.7:x86_64) digest='bb88dd5a780bf5d5524fb5912733920c2d9ea380f53c92ca697424e7840cb85c' ;;
    22.03.7:x86_64) digest='c90cbf5deee6d6b5de2adfde003850a6bb4912b60252be58c86b35916aaaa23b' ;;
    22.03.7:aarch64_cortex-a53) digest='bb588311a7eb45abca95782d75f8c1d77e20c56d29ca2445301409ffaf46e848' ;;
    23.05.6:x86_64) digest='983694174e8418004f1bd908e1f2b79e9773de38ae777bf1cf2cf52d89336967' ;;
    23.05.6:aarch64_generic) digest='a885ce800be199d22b814bf156d616f37a477d6ce59dff7b4320804cb378f6fb' ;;
    23.05.6:arm_cortex-a15_neon-vfpv4) digest='384ccd6cbc2a5572ecd1950b2f3f296c8ed7bbce120ede8e447db6cb12ade053' ;;
    24.10.8:x86_64) digest='4be85823e7373831c1115198a327fa4b624a4b77fddeb6d5d4b7b9f2bb20f1a9' ;;
    24.10.8:i386_pentium4) digest='d81f1aa17969f785408434d76ad49fb7ab650cf39a4601e8197f343e5c5dc6b4' ;;
    24.10.8:aarch64_generic) digest='834e3667b759e5305e3004c965fcb43ed3d51247a696f9814b8b5a20c861b912' ;;
    24.10.8:arm_cortex-a15_neon-vfpv4) digest='e24627486ba98f213e92ca5fd6404b8b09f928bada1e38d174164f3b774e0180' ;;
    25.12.5:x86_64) digest='642e6c6fb62509853a9f60580058a30db1e9e6cd325a379ad42739d5d60de649' ;;
    25.12.5:aarch64_generic) digest='73b29e5d02f8a8ff184e6e8b22b3a4fb88e0a6580fbf5b952e7733e661f01152' ;;
    25.12.5:arm_cortex-a15_neon-vfpv4) digest='39e496d32b30718c8d5c0d36717255dedf47081e9110b8e9e4c526f54ded11bc' ;;
    25.12.5:i386_pentium4) digest='f687d342f6639fe09bf24afb1cc597053c5e3639807befdb4fe50610ca1fcb5c' ;;
    *)
        case "$(uname -m):$arch" in
        x86_64:x86_64|x86_64:amd64) digest='5885cd87134337c07e275bb550970cb9e42213bb522ca30aa1fe72783df4cd6e' ;;
        aarch64:aarch64_*|aarch64:aarch64|aarch64:arm64) digest='c2ed75052b55e5dc136a6ff156caa1207c6ac9218c531b2238980cde37332fcf' ;;
        armv[78]*:arm_cortex-a*|armv[78]*:armv7) digest='04dc43eb95f63f9b65e1dbabba94a0da1e7518805edeb07a6505af4540c413e0' ;;
        armv[678]*:arm_arm1176*|armv[678]*:arm_mpcore*|armv[678]*:armv6) digest='73ec274dc0564a0d009f94e7fe6cc5ec0f7804c6a211d0547dc45b4cb1f1608b' ;;
        armv[5-8]*:arm_arm926*|armv[5-8]*:arm_xscale*|armv[5-8]*:arm_fa526*|armv[5-8]*:armv5) digest='6ca00239ca2250a3851ff603e07d7bcace0b6118d887d21e467bd48b557f8274' ;;
        i?86:i386*|i?86:386|i?86:x86|x86_64:i386*|x86_64:386|x86_64:x86) digest='44f6c664fc3e595341efb5020564aa15def26d6bc6ca8ce8eb8ed94123f4f67d' ;;
        mips*:mips_*|mips*:mips) digest='af554f740afb1b9ffb42360078b5924c939afdba3eb6845ee75de6ee9fd741b3' ;;
        mips*:mipsel_*|mips*:mipsle) digest='6e5b2cff9c5c243897e4ffea9b0ad53237c427d87566a57122668e57c81cb6b6' ;;
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
