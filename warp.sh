#!/usr/bin/env bash
set -Eeuo pipefail

readonly TRACE_URL="https://www.cloudflare.com/cdn-cgi/trace"
readonly WARP_KEY_URL="https://pkg.cloudflareclient.com/pubkey.gpg"
readonly WARP_REPO_URL="https://pkg.cloudflareclient.com/cloudflare-warp-ascii.repo"

tmp_file=""

trap cleanup EXIT

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

log() {
    printf '%s\n' "$*"
}

usage() {
    cat <<'EOF'
Install and connect the official Cloudflare WARP client.

Usage:
  sudo bash warp.sh
  sudo bash warp.sh --help

This installs the official consumer WARP client, registers it if needed,
connects it, and checks the resulting connection.
EOF
}

case "${1:-}" in
    --help|-h)
        usage
        exit 0
        ;;
    "")
        ;;
    *)
        usage >&2
        die "Unknown option: $1"
        ;;
esac

[[ "$EUID" -eq 0 ]] || die "Run this script as root, for example: sudo bash warp.sh"
[[ -r /etc/os-release ]] || die "Cannot identify this Linux distribution."
command -v systemctl >/dev/null 2>&1 || die "This installer requires systemd."

# shellcheck disable=SC1091
source /etc/os-release

id_like="${ID_LIKE:-}"

if [[ "$ID" == "ubuntu" || " $id_like " == *" ubuntu "* ]]; then
    package_family="debian"
    distro_codename="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
    [[ -n "$distro_codename" ]] ||
        die "Could not determine the Ubuntu base release codename."

elif [[ "$ID" == "debian" ]]; then
    package_family="debian"
    distro_codename="${VERSION_CODENAME:-}"
    [[ -n "$distro_codename" ]] ||
        die "Could not determine the Debian release codename."

elif [[ "$ID" == "fedora" ]]; then
    package_family="fedora"

elif [[ "$ID" == "rhel" || "$ID" == "centos" || " $id_like " == *" rhel "* ]]; then
    package_family="rhel"

else
    die "Unsupported distribution: ${PRETTY_NAME:-$ID}. Supported bases are Ubuntu, Debian, Fedora, RHEL, and CentOS."
fi

log "Detected: ${PRETTY_NAME:-$ID}"
log "Installing Cloudflare WARP from Cloudflare's official package repository..."

if [[ "$package_family" == "debian" ]]; then
    command -v apt-get >/dev/null 2>&1 || die "apt-get is required for this distribution."
    command -v gpg >/dev/null 2>&1 || true

    apt-get update
    apt-get install -y ca-certificates curl gnupg

    command -v curl >/dev/null 2>&1 || die "curl could not be installed."
    command -v gpg >/dev/null 2>&1 || die "gnupg could not be installed."

    install -d -m 0755 /usr/share/keyrings
    tmp_file="$(mktemp)"
    curl -fsSL "$WARP_KEY_URL" -o "$tmp_file"
    gpg --dearmor --yes --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg "$tmp_file"
    chmod 0644 /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
    rm -f "$tmp_file"
    tmp_file=""

    printf 'deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ %s main\n' \
        "$distro_codename" \
        > /etc/apt/sources.list.d/cloudflare-client.list

    apt-get update
    apt-get install -y cloudflare-warp

else
    if command -v dnf >/dev/null 2>&1; then
        package_manager="dnf"
    elif command -v yum >/dev/null 2>&1; then
        package_manager="yum"
    else
        die "Neither dnf nor yum is available."
    fi

    "$package_manager" install -y ca-certificates curl
    command -v curl >/dev/null 2>&1 || die "curl could not be installed."

    # Cloudflare's current package instructions require EPEL for RHEL 9+.
    if [[ "$package_family" == "rhel" ]]; then
        major_version="${VERSION_ID%%.*}"
        if [[ "$major_version" =~ ^[0-9]+$ ]] && (( major_version >= 9 )); then
            "$package_manager" install -y epel-release
        fi
    fi

    install -d -m 0755 /etc/yum.repos.d

    tmp_file="$(mktemp)"
    curl -fsSL "$WARP_KEY_URL" -o "$tmp_file"
    rpm --import "$tmp_file"
    rm -f "$tmp_file"
    tmp_file=""

    tmp_file="$(mktemp)"
    curl -fsSL "$WARP_REPO_URL" -o "$tmp_file"
    install -m 0644 "$tmp_file" /etc/yum.repos.d/cloudflare-warp.repo
    rm -f "$tmp_file"
    tmp_file=""

    "$package_manager" install -y cloudflare-warp
fi

command -v warp-cli >/dev/null 2>&1 ||
    die "The package was installed, but warp-cli is not available."

systemctl enable --now warp-svc

# A successful registration query indicates this client is already registered.
# Otherwise, create the standard consumer WARP registration.
if ! warp-cli registration show >/dev/null 2>&1; then
    log "Registering this device with WARP..."
    warp-cli registration new
fi

log "Connecting to WARP..."
warp-cli connect

log "Checking the WARP connection..."
for attempt in {1..10}; do
    if trace="$(curl -fsS --connect-timeout 3 --max-time 8 "$TRACE_URL" 2>/dev/null)" &&
        grep -Eq '^warp=(on|plus)$' <<<"$trace"; then
        log "WARP is connected and verified."
        exit 0
    fi
    sleep 1
done

warp-cli status || true
die "The client installed, but the WARP connection could not be verified. Check the network and try: sudo warp-cli status"
