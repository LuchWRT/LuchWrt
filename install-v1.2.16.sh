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
    17.01.7:x86_64) digest='f637e26d1fbe39a36d9c58e8676521f3d72da475700782989abfba119082436b' ;;
    18.06.9:x86_64) digest='243ba949c816668faf7c1836522a062ac58e60b167a4d776e71f7efa225adbf3' ;;
    19.07.10:x86_64) digest='d7fcd33725464eda12e1258cef8281b4f785831826f2fd2ff1f9801d65a7e156' ;;
    21.02.7:x86_64) digest='720073a0652dcbdc45ef1ad69132e05e07c07d04ea6f3642df94967a4183a4a2' ;;
    22.03.7:aarch64_cortex-a53) digest='b812619a18070e5699d4ff6f8a0cd276d9d423865326bb4e8c378001663d8456' ;;
    22.03.7:x86_64) digest='a5b70a94299e4dbabef67d186d82f2191490b2d6268318802f90b3aed463e5e3' ;;
    23.05.6:aarch64_generic) digest='dbb2e5e673f8e2dfb88eb1bb0fb2c80c9b3f9f333667c3792fa2aa3d05307df5' ;;
    23.05.6:arm_cortex-a15_neon-vfpv4) digest='7cdc8cfc50aba1b958fe7853b1269411c1404fea4e83b12a3ccfcdb3e873d89b' ;;
    23.05.6:x86_64) digest='2b6999b9a8b88510cb1b973f3d692ee08aeb835374b43aff7ef2de7c4870df52' ;;
    24.10.8:aarch64_generic) digest='caa292684508ecc81949637127acb5674433216faad544b39300ff0d113b38d9' ;;
    24.10.8:arm_cortex-a15_neon-vfpv4) digest='477242ba1e252331032f0b8d7291cf75239498c4772ec635a5f7f46458e7aadf' ;;
    24.10.8:i386_pentium4) digest='cc641d4a17adf7a806c8b5958e0a62428baa9451001806e9511031c6288a4cae' ;;
    24.10.8:x86_64) digest='ecbc13fe5ec0b689d6a33a554cff030bec8af9dae19f3c37de0958776ac341ba' ;;
    25.12.5:aarch64_generic) digest='9ea74dfdde5c793cd22240ab2c710c7b5a3a58716d195bed2bd3010de6f96ac2' ;;
    25.12.5:arm_cortex-a15_neon-vfpv4) digest='4503abfe93ca2655d4c82e259f1c76f34b9e5943a4cb1818bc52d1bc8a8c8769' ;;
    25.12.5:i386_pentium4) digest='351de069cca9af4a866dc067f3a03550830281865c4b44dfeec9928ae63f0280' ;;
    25.12.5:x86_64) digest='6e8c54b1c31974f1f8b0186765c0467c66d0ca2b8f1c14154feda5262afb4ad6' ;;
    25.12.6:aarch64_generic) digest='7bf6989fc5e75f714e47c0bbbab7c5efb8170d260a6b80c91a71cc91cec1d29b' ;;
    *)
        case "$(uname -m):$arch" in
        i?86:i386*|i?86:386|i?86:x86|x86_64:i386*|x86_64:386|x86_64:x86) digest='e3d7eeb794a7a48ecd5fe9b54981601494a9073fca37dd677fa045a802200a4c' ;;
        x86_64:x86_64|x86_64:amd64) digest='db8f0d1af2bb36473e6d1b87df138140e30e48de10956495819f167b1f64e14f' ;;
        aarch64:aarch64_*|aarch64:aarch64|aarch64:arm64) digest='913a2f1b80864a086a5c38b162a161d8d3734933d927616afa5fbd3d3822dad2' ;;
        armv[5-8]*:arm_arm926*|armv[5-8]*:arm_xscale*|armv[5-8]*:arm_fa526*|armv[5-8]*:armv5) digest='c7d8b50b3032f5186e0c8a6366b8ffb8070d56eec9a2f53569ed56ede3d5afe1' ;;
        armv[678]*:arm_arm1176*|armv[678]*:arm_mpcore*|armv[678]*:armv6) digest='b4aa334de4d9899a2b0afab4f75da8bf3dd62eccb0b6694aefe6bfadafb02133' ;;
        armv[78]*:arm_cortex-a*|armv[78]*:armv7) digest='044ff0103f49888b69d1730c375b4a0f2e16ea7d15f51810e9855d243a82a66c' ;;
        mips*:mips_*|mips*:mips) digest='97e9a6d78288e89a5ebcc4dae791c1b1aabee7da75a0b4423780ca17158db154' ;;
        mips*:mipsel_*|mips*:mipsle) digest='0ea5f59fb98935a73b5bf3d3d88f59d77923ac1bd5e1aec52017ad33213f4330' ;;
        *) fail 'для процессора этого роутера пока нет подписанной сборки Luch' ;;
        esac ;;
esac
tmp=$(mktemp /tmp/luch-bootstrap.XXXXXX) || fail 'не удалось создать временный файл'
trap 'exit 1' 1 2 3 15
retry() { attempts=$1; shift; delay=2; while ! "$@"; do attempts=$((attempts - 1)); [ "$attempts" -gt 0 ] || return 1; sleep "$delay"; delay=$((delay * 2)); done; }
url='https://github.com/LuchWRT/LuchWrt/releases/download/v1.2.16/bootstrap-'$digest'.sh'
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
