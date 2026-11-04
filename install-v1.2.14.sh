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
    17.01.7:x86_64) digest='a840a149e6d04cd3bc401e5c1e0c370532713200497995d23feca344f3de77b8' ;;
    18.06.9:x86_64) digest='482ef3a4c3a4c7af44f3d2eac249dc30e8cf00f1365f4905f926f5a36a507073' ;;
    19.07.10:x86_64) digest='b5626528cdbfbf763599b559f74fcf95e4099b4baaaa7d3d9e751ec32ec913ac' ;;
    21.02.7:x86_64) digest='642e50718338b038459db979a1e56cb11e5cecde2ebdd9b53de367f63e656622' ;;
    22.03.7:aarch64_cortex-a53) digest='e3d6056959cc0f18d85cf5a326fc722bdf066187a3c09454d6dcb702d1328f16' ;;
    22.03.7:x86_64) digest='0462f833a564354a368d34a8e53cee08d6ba4886c288b791c8391039a575005f' ;;
    23.05.6:aarch64_generic) digest='3ab3d4316602a9812a0116efb3f16a3656000debd17e296ab873297c45863775' ;;
    23.05.6:arm_cortex-a15_neon-vfpv4) digest='67e82d02caaae3fd14c6766c8060094df7c0c21b8ed6fea6a8b41cddf1621e32' ;;
    23.05.6:x86_64) digest='ffaca98c5f0591329e11b3a3db18b367dce039baa15087471b25f3eed4969080' ;;
    24.10.8:aarch64_generic) digest='8354af5acedaec7e35e9bdb076ad6add8e84194e9b92e07d2f9260f85159cf34' ;;
    24.10.8:arm_cortex-a15_neon-vfpv4) digest='11cc1e622861f8594b837e407f241109a1354b5692d7664eb25ef3f43db2a210' ;;
    24.10.8:i386_pentium4) digest='eab9245cb295dff5fcb3d08de70f1bee392bc67181205eaf1c2525cb7f480a17' ;;
    24.10.8:x86_64) digest='5f8efe6b56a605f663d899a5aaa78952b9d657656f5bea501a63d30a1e12ec4e' ;;
    25.12.5:aarch64_generic) digest='072b24948b6ca37366723f8755e5e468cf59034081afd97542a5e7e7805840d8' ;;
    25.12.5:arm_cortex-a15_neon-vfpv4) digest='9ae49c65be3a63e1cc7dd03136c0f13b2eeca8369e2578f0d88a451377935765' ;;
    25.12.5:i386_pentium4) digest='81fa4c732fdc09cda7546c87abdbf2cbca587138f0da7aec788b1fe3641f28d7' ;;
    25.12.5:x86_64) digest='e9774a432f95a371103c0c7d05967f648538c4040041b67f9d24ed5d6f265abd' ;;
    *)
        case "$(uname -m):$arch" in
        i?86:i386*|i?86:386|i?86:x86|x86_64:i386*|x86_64:386|x86_64:x86) digest='5eee04e85c768ef95f2c59696b488862c627d5492661c89ce38d35104ca35e32' ;;
        x86_64:x86_64|x86_64:amd64) digest='187aef1b5c6226df263021f8da453d72c326787f157639b15dc7230641cb9ff3' ;;
        aarch64:aarch64_*|aarch64:aarch64|aarch64:arm64) digest='0b9b796f1aa1db9ad4ab773f4c50f354d27f188a96fb506964ee94ebb4137d9f' ;;
        armv[5-8]*:arm_arm926*|armv[5-8]*:arm_xscale*|armv[5-8]*:arm_fa526*|armv[5-8]*:armv5) digest='50858be42b16b75208b61988d6e7885f75c825b589757314677e62497bf357cd' ;;
        armv[678]*:arm_arm1176*|armv[678]*:arm_mpcore*|armv[678]*:armv6) digest='7a305781bc4c149b3f8d266a477402aa74acbbfb239c0bf0aef920e757a5e365' ;;
        armv[78]*:arm_cortex-a*|armv[78]*:armv7) digest='58e4279520459c1b891a530dbf07434298cd6a1649593db6df6a43b588d6d733' ;;
        mips*:mips_*|mips*:mips) digest='e86d54f99c6694df478238115cd5675b1d008833b9c5b7b68503ca375b2de062' ;;
        mips*:mipsel_*|mips*:mipsle) digest='d77716a8f4af3ea8881067fe16cac6f4cbbade9e03c2e4272e0c8f019bd05694' ;;
        *) fail 'для процессора этого роутера пока нет подписанной сборки Luch' ;;
        esac ;;
esac
tmp=$(mktemp /tmp/luch-bootstrap.XXXXXX) || fail 'не удалось создать временный файл'
trap 'exit 1' 1 2 3 15
retry() { attempts=$1; shift; delay=2; while ! "$@"; do attempts=$((attempts - 1)); [ "$attempts" -gt 0 ] || return 1; sleep "$delay"; delay=$((delay * 2)); done; }
url='https://github.com/LuchWRT/LuchWrt/releases/download/v1.2.14/bootstrap-'$digest'.sh'
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
