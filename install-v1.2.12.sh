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
    17.01.7:x86_64) digest='6506fa4a044a1dc3e3eac6d2d49143f9dbf7a62f37ee6f3d3945daaf674bd269' ;;
    18.06.9:x86_64) digest='0dc405a0ecad7e72beb99b9ee31a4662f7852f11014478168574ccffadce9cc1' ;;
    19.07.10:x86_64) digest='66718e10c72812fd8001503833ba6c8c4ab803c8640728106a64a0f32f5c644a' ;;
    21.02.7:x86_64) digest='d12f1e59d82e5273f16d6c6f8e85d26d11bd57454fcb27e008e34e187a682691' ;;
    22.03.7:aarch64_cortex-a53) digest='35f4286faef2c026c02c69a1a05adfc3b64e22a91dfb790c1ba30bb6d6593ce8' ;;
    22.03.7:x86_64) digest='095360fa53c22e813aaa0de148349ea0cfa49c12ce6d40a4b6b1ebbe1019bd75' ;;
    23.05.6:aarch64_generic) digest='e7c5a55de3ee72787dce14b7071572acb2392e664158f4576832934737454ebb' ;;
    23.05.6:arm_cortex-a15_neon-vfpv4) digest='6809080c5ff32ad47b2ad3f735b1f05812e7f275d9b537a4a8e7103135e13dc7' ;;
    23.05.6:x86_64) digest='5cb3c79862ea3730cebfee9c0d138e53bb4d0b22f599ecb3bf307480171a3c7e' ;;
    24.10.8:aarch64_generic) digest='bc1d7df983486c9a8e5a0f500368903934b0e24e4925e6da02ec749e3bc4c195' ;;
    24.10.8:arm_cortex-a15_neon-vfpv4) digest='593d8ebed111462061748000d495effd83fc037940615834ffab277d8ba2661f' ;;
    24.10.8:i386_pentium4) digest='e822f67b3151364ca6cecd6478ca421a3a27e4e6c1b53b1b1379316a817d1579' ;;
    24.10.8:x86_64) digest='ce779d2a530de2e4dc4c1a1a9cc99bf343f403b4e6ff587a04203bb87a25891e' ;;
    25.12.5:aarch64_generic) digest='6667daf6a8b4b4d0a9db1bb39e8410f170b7bc840c2d07b2b1580fbd349a225e' ;;
    25.12.5:arm_cortex-a15_neon-vfpv4) digest='a17d614399a1b6853f7455dbc75ff0aef77242d5ebd2d345d1d70049b7a1a0ed' ;;
    25.12.5:i386_pentium4) digest='84268bbdcfa5038a47bdefe51c86887db5244e945ee4117d076a668d1b742fd1' ;;
    25.12.5:x86_64) digest='6403ec9a254c4684d77ff9692f6897964dac714d9f6dd0140c5efe44f63f6864' ;;
    *)
        case "$(uname -m):$arch" in
        i?86:i386*|i?86:386|i?86:x86|x86_64:i386*|x86_64:386|x86_64:x86) digest='99e5616edb93224a4c27cee8a53ab736de4a383eded6e79e78ea6e9d09940cad' ;;
        x86_64:x86_64|x86_64:amd64) digest='c0b47833fed34606c99fa9308b2f1fe63060a2bc6f2b48a1af23a32e5021a100' ;;
        aarch64:aarch64_*|aarch64:aarch64|aarch64:arm64) digest='cfa802c315f950a85270998ed4706b1b85eb34ebe1b3d822199a78ae052b1be1' ;;
        armv[5-8]*:arm_arm926*|armv[5-8]*:arm_xscale*|armv[5-8]*:arm_fa526*|armv[5-8]*:armv5) digest='fe6b49fb917fc1a37d692799ac20fc412615dc295ad7a669b9cbd8540b03107a' ;;
        armv[678]*:arm_arm1176*|armv[678]*:arm_mpcore*|armv[678]*:armv6) digest='589ec0671e4ef45e2cb0a79d3b96a8865eca15e07760ab2eafb0a800335dfee0' ;;
        armv[78]*:arm_cortex-a*|armv[78]*:armv7) digest='428637aaddf573387663d368342226b0a6b64c468c8271cd393130ea85fbcbb9' ;;
        mips*:mips_*|mips*:mips) digest='1c50e98d22cbd44b9cc52d913814ac65a25604a7a4cf05068bb6f7150b3e6ec9' ;;
        mips*:mipsel_*|mips*:mipsle) digest='4d5fc6744714875467cb46b155cccccf8fccc81fa48d46ee014aa89f2761e92a' ;;
        *) fail 'для процессора этого роутера пока нет подписанной сборки Luch' ;;
        esac ;;
esac
tmp=$(mktemp /tmp/luch-bootstrap.XXXXXX) || fail 'не удалось создать временный файл'
trap 'exit 1' 1 2 3 15
retry() { attempts=$1; shift; delay=2; while ! "$@"; do attempts=$((attempts - 1)); [ "$attempts" -gt 0 ] || return 1; sleep "$delay"; delay=$((delay * 2)); done; }
url='https://github.com/LuchWRT/LuchWrt/releases/download/v1.2.12/bootstrap-'$digest'.sh'
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
