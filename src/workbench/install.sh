#!/bin/sh
set -eu

CODEX_VERSION="0.144.3"
CLAUDE_VERSION="2.1.197-1"
PI_VERSION="0.80.6"
HUNK_VERSION="0.17.0"
WORKTRUNK_VERSION="0.67.0"
GLOW_VERSION="2.1.2"
FD_VERSION="10.4.2"
RIPGREP_VERSION="15.1.0"
LAZYGIT_VERSION="0.63.0"
BAT_VERSION="0.26.1"
DELTA_VERSION="0.19.2"
HERDR_VERSION="0.7.3"
NVIM_VERSION="0.12.4"
GH_VERSION="2.96.0"
FZF_VERSION="0.74.0"
ZOXIDE_VERSION="0.10.0"
STARSHIP_VERSION="1.26.0"

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
        lazygit_asset="lazygit_${LAZYGIT_VERSION}_linux_x86_64.tar.gz"
        lazygit_sha256="cf5cfa3e116d7775f3600a51ec1d9ce7ba554a08b9566c7c2da83cb0023efabf"
        bat_asset="bat_${BAT_VERSION}_amd64.deb"
        bat_sha256="ad59954aa1540e526f97267f60557ea5ef4c7dcf91a0811254134537cb353a3c"
        delta_asset="git-delta_${DELTA_VERSION}_amd64.deb"
        delta_sha256="ea4f0222950ee750a3d38dd80d03bce4cee07a3f63928fc47548383bcaf23093"
        herdr_asset="herdr-linux-x86_64"
        herdr_sha256="043ef43ecbabda28465dcff1eec3184518150d567b8b8f20cda9c6c88770641d"
        nvim_target="nvim-linux-x86_64"
        nvim_sha256="012bf3fcac5ade43914df3f174668bf64d05e049a4f032a388c027b1ebd78628"
        gh_asset="gh_${GH_VERSION}_linux_amd64.deb"
        gh_sha256="11a731f4e0ca8c3db96ef6d2cc404dcab3d78247ce0e07c53e07117e7627d6a1"
        fzf_asset="fzf-${FZF_VERSION}-linux_amd64.tar.gz"
        fzf_sha256="cf919f05b7581b4c744d764eaa704665d61dd6d3ca785f0df2351281dff60cda"
        zoxide_target="x86_64-unknown-linux-musl"
        zoxide_sha256="2d93385b99f3e82cf2701609a1bffcad863fbeb75aa3fe7eb6be4d29be68b1ae"
        starship_target="x86_64-unknown-linux-musl"
        starship_sha256="b7c232b0e8249d8e55a40beb79c5c43a7d370f3f9408bd215deb0170daeaadf3"
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
        lazygit_asset="lazygit_${LAZYGIT_VERSION}_linux_arm64.tar.gz"
        lazygit_sha256="aac147abf5ce43afe6ae8bcb14b0d479111975a189302d7a99386deca70d57f7"
        bat_asset="bat_${BAT_VERSION}_arm64.deb"
        bat_sha256="4a70c3f6236f2c621bd68357257e21b78c9497de4de1e803301ec0209f168653"
        delta_asset="git-delta_${DELTA_VERSION}_arm64.deb"
        delta_sha256="0edc36cf514f1bd84becac3e94ee8ae9f8818c6a1f99f7b2ee67b362afa253d3"
        herdr_asset="herdr-linux-aarch64"
        herdr_sha256="ea490094f2c7c39099870857d00c64c628ef7b5eba1967df4258033455ee2cb1"
        nvim_target="nvim-linux-arm64"
        nvim_sha256="ceb7e88c6b681f0515d135dcdfad54f5eb4373b25ce6172197cd9a69c758063f"
        gh_asset="gh_${GH_VERSION}_linux_arm64.deb"
        gh_sha256="334dd9c6704fc1656a48e475c5a3a9aa32bbadb87fa1777513bc626af4a99e89"
        fzf_asset="fzf-${FZF_VERSION}-linux_arm64.tar.gz"
        fzf_sha256="bd9e6165ebdb702215d42368cbb95b8dd70a4e77ee97925adac8c31660e30ef7"
        zoxide_target="aarch64-unknown-linux-musl"
        zoxide_sha256="f1f16c5d6298d63dee467eedea1cdcd8490e43e493bea43acd416dc9033ef641"
        starship_target="aarch64-unknown-linux-musl"
        starship_sha256="dc30189378d2f2e287384e8a692d3f95ad1df64cf0e8c36aa9201516028aed6b"
        ;;
    *)
        echo "Unsupported architecture '$architecture'. Supported architectures: amd64, arm64." >&2
        exit 1
        ;;
esac

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl tar xz-utils zsh

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

echo "Installing Debian packages..."
download_and_verify \
    "https://downloads.claude.ai/claude-code/apt/stable/pool/main/c/claude-code/$claude_asset" \
    "$claude_sha256" "$tmp_dir/$claude_asset"
download_and_verify \
    "https://github.com/sharkdp/fd/releases/download/v${FD_VERSION}/$fd_asset" \
    "$fd_sha256" "$tmp_dir/$fd_asset"
download_and_verify \
    "https://github.com/sharkdp/bat/releases/download/v${BAT_VERSION}/$bat_asset" \
    "$bat_sha256" "$tmp_dir/$bat_asset"
download_and_verify \
    "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/$delta_asset" \
    "$delta_sha256" "$tmp_dir/$delta_asset"
download_and_verify \
    "https://github.com/cli/cli/releases/download/v${GH_VERSION}/$gh_asset" \
    "$gh_sha256" "$tmp_dir/$gh_asset"
apt-get install -y --no-install-recommends \
    "$tmp_dir/$claude_asset" \
    "$tmp_dir/$fd_asset" \
    "$tmp_dir/$bat_asset" \
    "$tmp_dir/$delta_asset" \
    "$tmp_dir/$gh_asset"

echo "Installing Node-based CLIs..."
if ! command -v npm >/dev/null 2>&1; then
    echo "npm was not found. The official Node Feature dependency must be installed first." >&2
    exit 1
fi
npm install --global --prefix /usr/local --ignore-scripts --no-audit --no-fund \
    "@openai/codex@$CODEX_VERSION" \
    "@earendil-works/pi-coding-agent@$PI_VERSION" \
    "hunkdiff@$HUNK_VERSION"

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

echo "Installing Lazygit $LAZYGIT_VERSION..."
download_and_verify \
    "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/$lazygit_asset" \
    "$lazygit_sha256" "$tmp_dir/$lazygit_asset"
mkdir -p "$tmp_dir/lazygit"
tar -xzf "$tmp_dir/$lazygit_asset" -C "$tmp_dir/lazygit"
install -m 0755 "$tmp_dir/lazygit/lazygit" /usr/local/bin/lazygit

echo "Installing Herdr $HERDR_VERSION..."
download_and_verify \
    "https://github.com/ogulcancelik/herdr/releases/download/v${HERDR_VERSION}/$herdr_asset" \
    "$herdr_sha256" "$tmp_dir/$herdr_asset"
install -m 0755 "$tmp_dir/$herdr_asset" /usr/local/bin/herdr

nvim_asset="${nvim_target}.tar.gz"
echo "Installing Neovim $NVIM_VERSION..."
download_and_verify \
    "https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/$nvim_asset" \
    "$nvim_sha256" "$tmp_dir/$nvim_asset"
mkdir -p "$tmp_dir/nvim"
tar -xzf "$tmp_dir/$nvim_asset" -C "$tmp_dir/nvim"
nvim_install_dir="/opt/nvim-${NVIM_VERSION}-${architecture}"
rm -rf "$nvim_install_dir"
mkdir -p "$nvim_install_dir"
cp -a "$tmp_dir/nvim/$nvim_target/." "$nvim_install_dir/"
ln -sfn "$nvim_install_dir/bin/nvim" /usr/local/bin/nvim

echo "Installing fzf $FZF_VERSION..."
download_and_verify \
    "https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/$fzf_asset" \
    "$fzf_sha256" "$tmp_dir/$fzf_asset"
mkdir -p "$tmp_dir/fzf"
tar -xzf "$tmp_dir/$fzf_asset" -C "$tmp_dir/fzf"
install -m 0755 "$tmp_dir/fzf/fzf" /usr/local/bin/fzf

zoxide_asset="zoxide-${ZOXIDE_VERSION}-${zoxide_target}.tar.gz"
echo "Installing zoxide $ZOXIDE_VERSION..."
download_and_verify \
    "https://github.com/ajeetdsouza/zoxide/releases/download/v${ZOXIDE_VERSION}/$zoxide_asset" \
    "$zoxide_sha256" "$tmp_dir/$zoxide_asset"
mkdir -p "$tmp_dir/zoxide"
tar -xzf "$tmp_dir/$zoxide_asset" -C "$tmp_dir/zoxide"
install -m 0755 "$tmp_dir/zoxide/zoxide" /usr/local/bin/zoxide

starship_asset="starship-${starship_target}.tar.gz"
echo "Installing Starship $STARSHIP_VERSION..."
download_and_verify \
    "https://github.com/starship/starship/releases/download/v${STARSHIP_VERSION}/$starship_asset" \
    "$starship_sha256" "$tmp_dir/$starship_asset"
mkdir -p "$tmp_dir/starship"
tar -xzf "$tmp_dir/$starship_asset" -C "$tmp_dir/starship"
install -m 0755 "$tmp_dir/starship/starship" /usr/local/bin/starship

# jq is provided by common-utils. Zsh comes from the distribution package.
# Everything installed here is root-owned and system-wide, so remote-user ownership is not needed.
# No credentials, shell initialization, login-shell changes, or agent configuration are installed.
echo "workbench Feature installation complete."
