#!/bin/sh
set -eu

CODEX_VERSION="0.144.3"
CLAUDE_VERSION="2.1.197-1"
PI_VERSION="0.80.6"
WORKTRUNK_VERSION="0.67.0"
GLOW_VERSION="2.1.2"
FD_VERSION="10.4.2"
RIPGREP_VERSION="15.1.0"

if [ "$(id -u)" -ne 0 ]; then
    echo "The workbench Feature installer must run as root." >&2
    exit 1
fi
if [ ! -r /etc/os-release ]; then
    echo "The workbench Feature supports Debian and Ubuntu only." >&2
    exit 1
fi

# shellcheck disable=SC1091
. /etc/os-release
case "${ID:-}:${ID_LIKE:-}" in
    *debian*|*ubuntu*) ;;
    *)
        echo "Unsupported distribution '${ID:-unknown}'. The workbench Feature supports Debian and Ubuntu only." >&2
        exit 1
        ;;
esac

architecture="$(dpkg --print-architecture)"
case "$architecture" in
    amd64)
        claude_asset="claude-code_${CLAUDE_VERSION}_amd64.deb"
        claude_sha256="4624070db76fa593f5a1481c6813f617d1631ec6b829508ea17cc15087b8fbec"
        fd_asset="fd-musl_${FD_VERSION}_amd64.deb"
        fd_sha256="a8d10259388c32f9aafd65fb65b6e3e2d2782043bed687112f50e2c4cf000c27"
        worktrunk_target="x86_64-unknown-linux-musl"
        worktrunk_sha256="f580b7d12ca9bd750c17e5af05f509f9dfa3523661b982572684c6f541cf661f"
        glow_target="x86_64"
        glow_sha256="6063d4f2af8a82a5f4bba0831e165de9381660aa8b41df4816d0106a265b07d5"
        ripgrep_target="x86_64-unknown-linux-musl"
        ripgrep_sha256="1c9297be4a084eea7ecaedf93eb03d058d6faae29bbc57ecdaf5063921491599"
        ;;
    arm64)
        claude_asset="claude-code_${CLAUDE_VERSION}_arm64.deb"
        claude_sha256="cb132350b4700246bf8e02ae4b2c3d779a1d57d40f0b69282b581a09d16a6c90"
        fd_asset="fd-musl_${FD_VERSION}_arm64.deb"
        fd_sha256="8dceaa1186be94c3ec29e87781b1e1d48395269e8dcf318dfa1cd1c56dbfa959"
        worktrunk_target="aarch64-unknown-linux-musl"
        worktrunk_sha256="5bf0590928a3db4751d1508007ba9f164cd49e75930565f5868136e351368adc"
        glow_target="arm64"
        glow_sha256="cf63abebcb50b72909db965d78290e7cecbf17a900e84705dc84addbb6952099"
        ripgrep_target="aarch64-unknown-linux-gnu"
        ripgrep_sha256="2b661c6ef508e902f388e9098d9c4c5aca72c87b55922d94abdba830b4dc885e"
        ;;
    *)
        echo "Unsupported architecture '$architecture'. Supported architectures: amd64, arm64." >&2
        exit 1
        ;;
esac

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl tar xz-utils

tmp_dir="$(mktemp -d /tmp/workbench-feature.XXXXXX)"
cleanup() {
    rm -rf "$tmp_dir"
}
trap cleanup EXIT HUP INT TERM

download_and_verify() {
    url="$1"
    expected_sha256="$2"
    destination="$3"
    curl -fsSL --retry 5 --retry-delay 2 -o "$destination" "$url"
    printf '%s  %s\n' "$expected_sha256" "$destination" | sha256sum -c -
}

echo "Installing Claude Code ${CLAUDE_VERSION%-1} and fd $FD_VERSION..."
download_and_verify \
    "https://downloads.claude.ai/claude-code/apt/stable/pool/main/c/claude-code/$claude_asset" \
    "$claude_sha256" "$tmp_dir/$claude_asset"
download_and_verify \
    "https://github.com/sharkdp/fd/releases/download/v${FD_VERSION}/$fd_asset" \
    "$fd_sha256" "$tmp_dir/$fd_asset"
apt-get install -y --no-install-recommends "$tmp_dir/$claude_asset" "$tmp_dir/$fd_asset"

echo "Installing Codex CLI $CODEX_VERSION and Pi $PI_VERSION..."
if ! command -v npm >/dev/null 2>&1; then
    echo "npm was not found. The official Node Feature dependency must be installed first." >&2
    exit 1
fi
npm install --global --prefix /usr/local --ignore-scripts --no-audit --no-fund \
    "@openai/codex@$CODEX_VERSION" \
    "@earendil-works/pi-coding-agent@$PI_VERSION"

worktrunk_asset="worktrunk-${worktrunk_target}.tar.xz"
echo "Installing Worktrunk $WORKTRUNK_VERSION..."
download_and_verify \
    "https://github.com/max-sixty/worktrunk/releases/download/v${WORKTRUNK_VERSION}/$worktrunk_asset" \
    "$worktrunk_sha256" "$tmp_dir/$worktrunk_asset"
mkdir -p "$tmp_dir/worktrunk"
tar -xJf "$tmp_dir/$worktrunk_asset" -C "$tmp_dir/worktrunk"
install -m 0755 "$tmp_dir/worktrunk/worktrunk-${worktrunk_target}/wt" /usr/local/bin/wt

glow_asset="glow_${GLOW_VERSION}_Linux_${glow_target}.tar.gz"
echo "Installing Glow $GLOW_VERSION..."
download_and_verify \
    "https://github.com/charmbracelet/glow/releases/download/v${GLOW_VERSION}/$glow_asset" \
    "$glow_sha256" "$tmp_dir/$glow_asset"
mkdir -p "$tmp_dir/glow"
tar -xzf "$tmp_dir/$glow_asset" -C "$tmp_dir/glow"
install -m 0755 "$tmp_dir/glow/glow_${GLOW_VERSION}_Linux_${glow_target}/glow" /usr/local/bin/glow

ripgrep_asset="ripgrep-${RIPGREP_VERSION}-${ripgrep_target}.tar.gz"
echo "Installing ripgrep $RIPGREP_VERSION..."
download_and_verify \
    "https://github.com/BurntSushi/ripgrep/releases/download/${RIPGREP_VERSION}/$ripgrep_asset" \
    "$ripgrep_sha256" "$tmp_dir/$ripgrep_asset"
mkdir -p "$tmp_dir/ripgrep"
tar -xzf "$tmp_dir/$ripgrep_asset" -C "$tmp_dir/ripgrep"
install -m 0755 "$tmp_dir/ripgrep/ripgrep-${RIPGREP_VERSION}-${ripgrep_target}/rg" /usr/local/bin/rg

# All files are root-owned and system-wide, so remote-user ownership is not needed.
# No credentials, shell configuration, or agent configuration is installed.
echo "workbench Feature installation complete."
