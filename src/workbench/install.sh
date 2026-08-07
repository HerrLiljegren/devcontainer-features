#!/bin/sh
set -eu

feature_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck disable=SC1091
. "$feature_dir/versions.env"
# shellcheck disable=SC1091
. "$feature_dir/checksums.env"

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
        claude_sha256="$CLAUDE_SHA256_AMD64"
        fd_asset="fd-musl_${FD_VERSION}_amd64.deb"
        fd_sha256="$FD_SHA256_AMD64"
        worktrunk_target="x86_64-unknown-linux-musl"
        worktrunk_sha256="$WORKTRUNK_SHA256_AMD64"
        ripgrep_target="x86_64-unknown-linux-musl"
        ripgrep_sha256="$RIPGREP_SHA256_AMD64"
        lazygit_asset="lazygit_${LAZYGIT_VERSION}_linux_x86_64.tar.gz"
        lazygit_sha256="$LAZYGIT_SHA256_AMD64"
        bat_asset="bat_${BAT_VERSION}_amd64.deb"
        bat_sha256="$BAT_SHA256_AMD64"
        delta_asset="git-delta_${DELTA_VERSION}_amd64.deb"
        delta_sha256="$DELTA_SHA256_AMD64"
        nvim_target="nvim-linux-x86_64"
        nvim_sha256="$NVIM_SHA256_AMD64"
        gh_asset="gh_${GH_VERSION}_linux_amd64.deb"
        gh_sha256="$GH_SHA256_AMD64"
        fzf_asset="fzf-${FZF_VERSION}-linux_amd64.tar.gz"
        fzf_sha256="$FZF_SHA256_AMD64"
        zoxide_target="x86_64-unknown-linux-musl"
        zoxide_sha256="$ZOXIDE_SHA256_AMD64"
        starship_target="x86_64-unknown-linux-musl"
        starship_sha256="$STARSHIP_SHA256_AMD64"
        opencode_arch="x64"
        opencode_sha256="$OPENCODE_SHA256_AMD64"
        eza_target="x86_64-unknown-linux-musl"
        eza_sha256="$EZA_SHA256_AMD64"
        yq_arch="amd64"
        yq_sha256="$YQ_SHA256_AMD64"
        credential_provider_arch="x64"
        credential_provider_sha256="$ARTIFACTS_CREDENTIAL_PROVIDER_SHA256_AMD64"
        ;;
    arm64)
        claude_asset="claude-code_${CLAUDE_VERSION}_arm64.deb"
        claude_sha256="$CLAUDE_SHA256_ARM64"
        fd_asset="fd-musl_${FD_VERSION}_arm64.deb"
        fd_sha256="$FD_SHA256_ARM64"
        worktrunk_target="aarch64-unknown-linux-musl"
        worktrunk_sha256="$WORKTRUNK_SHA256_ARM64"
        ripgrep_target="aarch64-unknown-linux-gnu"
        ripgrep_sha256="$RIPGREP_SHA256_ARM64"
        lazygit_asset="lazygit_${LAZYGIT_VERSION}_linux_arm64.tar.gz"
        lazygit_sha256="$LAZYGIT_SHA256_ARM64"
        bat_asset="bat_${BAT_VERSION}_arm64.deb"
        bat_sha256="$BAT_SHA256_ARM64"
        delta_asset="git-delta_${DELTA_VERSION}_arm64.deb"
        delta_sha256="$DELTA_SHA256_ARM64"
        nvim_target="nvim-linux-arm64"
        nvim_sha256="$NVIM_SHA256_ARM64"
        gh_asset="gh_${GH_VERSION}_linux_arm64.deb"
        gh_sha256="$GH_SHA256_ARM64"
        fzf_asset="fzf-${FZF_VERSION}-linux_arm64.tar.gz"
        fzf_sha256="$FZF_SHA256_ARM64"
        zoxide_target="aarch64-unknown-linux-musl"
        zoxide_sha256="$ZOXIDE_SHA256_ARM64"
        starship_target="aarch64-unknown-linux-musl"
        starship_sha256="$STARSHIP_SHA256_ARM64"
        opencode_arch="arm64"
        opencode_sha256="$OPENCODE_SHA256_ARM64"
        eza_target="aarch64-unknown-linux-gnu"
        eza_sha256="$EZA_SHA256_ARM64"
        yq_arch="arm64"
        yq_sha256="$YQ_SHA256_ARM64"
        credential_provider_arch="arm64"
        credential_provider_sha256="$ARTIFACTS_CREDENTIAL_PROVIDER_SHA256_ARM64"
        ;;
    *)
        echo "Unsupported architecture '$architecture'. Supported architectures: amd64, arm64." >&2
        exit 1
        ;;
esac

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gzip \
    libsecret-1-0 \
    python3 \
    python3-venv \
    shellcheck \
    tar \
    xdg-utils \
    xz-utils

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
    "@azure-devops/mcp@$AZURE_DEVOPS_MCP_VERSION" \
    "hunkdiff@$HUNK_VERSION"

worktrunk_asset="worktrunk-${worktrunk_target}.tar.xz"
echo "Installing Worktrunk $WORKTRUNK_VERSION..."
download_and_verify \
    "https://github.com/max-sixty/worktrunk/releases/download/v${WORKTRUNK_VERSION}/$worktrunk_asset" \
    "$worktrunk_sha256" "$tmp_dir/$worktrunk_asset"
mkdir -p "$tmp_dir/worktrunk"
tar -xJf "$tmp_dir/$worktrunk_asset" -C "$tmp_dir/worktrunk"
install -m 0755 "$tmp_dir/worktrunk/worktrunk-${worktrunk_target}/wt" /usr/local/bin/wt

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

nvim_asset="${nvim_target}.tar.gz"
echo "Installing Neovim $NVIM_VERSION..."
download_and_verify \
    "https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/$nvim_asset" \
    "$nvim_sha256" "$tmp_dir/$nvim_asset"
mkdir -p "$tmp_dir/nvim"
tar -xzf "$tmp_dir/$nvim_asset" -C "$tmp_dir/nvim"
nvim_install_dir="/opt/nvim-${NVIM_VERSION}-${architecture}"
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

opencode_asset="opencode-linux-${opencode_arch}.tar.gz"
echo "Installing OpenCode $OPENCODE_VERSION..."
download_and_verify \
    "https://github.com/anomalyco/opencode/releases/download/v${OPENCODE_VERSION}/$opencode_asset" \
    "$opencode_sha256" "$tmp_dir/$opencode_asset"
mkdir -p "$tmp_dir/opencode"
tar -xzf "$tmp_dir/$opencode_asset" -C "$tmp_dir/opencode"
install -m 0755 "$tmp_dir/opencode/opencode" /usr/local/bin/opencode

eza_asset="eza_${eza_target}.tar.gz"
echo "Installing eza $EZA_VERSION..."
download_and_verify \
    "https://github.com/eza-community/eza/releases/download/v${EZA_VERSION}/$eza_asset" \
    "$eza_sha256" "$tmp_dir/$eza_asset"
mkdir -p "$tmp_dir/eza"
tar -xzf "$tmp_dir/$eza_asset" -C "$tmp_dir/eza"
install -m 0755 "$tmp_dir/eza/eza" /usr/local/bin/eza

yq_asset="yq_linux_${yq_arch}"
echo "Installing yq $YQ_VERSION..."
download_and_verify \
    "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/$yq_asset" \
    "$yq_sha256" "$tmp_dir/$yq_asset"
install -m 0755 "$tmp_dir/$yq_asset" /usr/local/bin/yq

credential_provider_asset="Microsoft.linux-${credential_provider_arch}.NuGet.CredentialProvider.tar.gz"
echo "Installing Azure Artifacts Credential Provider $ARTIFACTS_CREDENTIAL_PROVIDER_VERSION..."
download_and_verify \
    "https://github.com/microsoft/artifacts-credprovider/releases/download/v${ARTIFACTS_CREDENTIAL_PROVIDER_VERSION}/$credential_provider_asset" \
    "$credential_provider_sha256" "$tmp_dir/$credential_provider_asset"
mkdir -p /opt/workbench/nuget
tar -xzf "$tmp_dir/$credential_provider_asset" -C /opt/workbench/nuget plugins/netcore

echo "Installing dotfiles $DOTFILES_COMMIT..."
download_and_verify \
    "https://github.com/HerrLiljegren/dotfiles/archive/${DOTFILES_COMMIT}.tar.gz" \
    "$DOTFILES_SHA256" "$tmp_dir/dotfiles.tar.gz"
mkdir -p /opt/workbench/dotfiles
tar -xzf "$tmp_dir/dotfiles.tar.gz" -C /opt/workbench/dotfiles --strip-components=1

echo "Installing curated Matt Pocock skills $MATT_POCOCK_SKILLS_COMMIT..."
download_and_verify \
    "https://github.com/mattpocock/skills/archive/${MATT_POCOCK_SKILLS_COMMIT}.tar.gz" \
    "$MATT_POCOCK_SKILLS_SHA256" "$tmp_dir/matt-pocock-skills.tar.gz"
mkdir -p "$tmp_dir/matt-pocock-skills" /opt/workbench/skills/mattpocock
tar -xzf "$tmp_dir/matt-pocock-skills.tar.gz" -C "$tmp_dir/matt-pocock-skills"
for skill in \
    engineering/code-review \
    engineering/codebase-design \
    engineering/diagnosing-bugs \
    engineering/domain-modeling \
    engineering/grill-with-docs \
    engineering/implement \
    engineering/improve-codebase-architecture \
    engineering/prototype \
    engineering/research \
    engineering/resolving-merge-conflicts \
    engineering/tdd \
    engineering/to-spec \
    engineering/to-tickets \
    engineering/triage \
    engineering/wayfinder \
    engineering/wizard \
    productivity/grill-me \
    productivity/grilling \
    productivity/handoff \
    productivity/writing-for-agents
do
    cp -a \
        "$tmp_dir/matt-pocock-skills/skills-$MATT_POCOCK_SKILLS_COMMIT/skills/$skill" \
        "/opt/workbench/skills/mattpocock/${skill##*/}"
done

install -m 0644 "$feature_dir/versions.env" /opt/workbench/versions.env
install -m 0755 "$feature_dir/on-create.sh" /usr/local/bin/workbench-on-create
install -m 0755 "$feature_dir/azure-devops-mcp.sh" /usr/local/bin/workbench-azure-devops-mcp

remote_user="${_REMOTE_USER:?The Dev Container remote user was not provided}"
remote_group="$(id -gn "$remote_user")"
install -d -m 0700 -o "$remote_user" -g "$remote_group" /workbench-state

rm -rf /var/lib/apt/lists/*
echo "workbench Feature installation complete."
