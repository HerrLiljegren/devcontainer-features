#!/bin/sh
set -eu

state_dir="${WORKBENCH_STATE_DIR:-/workbench-state}"

link_directory() {
    destination="$1"
    source="$2"

    if [ -e "$destination" ] && [ ! -L "$destination" ]; then
        echo "workbench: refusing to replace existing directory $destination" >&2
        exit 1
    fi

    mkdir -p "$(dirname "$destination")" "$source"
    ln -sfn "$source" "$destination"
}

umask 077
mkdir -p \
    "$state_dir/azure-artifacts/MicrosoftCredentialProvider" \
    "$state_dir/azure-devops-mcp" \
    "$state_dir/claude" \
    "$state_dir/codex" \
    "$state_dir/gh" \
    "$state_dir/opencode" \
    "$state_dir/shell"

link_directory "$HOME/.codex" "$state_dir/codex"
link_directory "$HOME/.claude" "$state_dir/claude"
link_directory "$HOME/.local/share/opencode" "$state_dir/opencode"
link_directory \
    "$HOME/.local/share/MicrosoftCredentialProvider" \
    "$state_dir/azure-artifacts/MicrosoftCredentialProvider"

mkdir -p "$HOME/.nuget/plugins/netcore"
ln -sfn \
    /opt/workbench/nuget/plugins/netcore/CredentialProvider.Microsoft \
    "$HOME/.nuget/plugins/netcore/CredentialProvider.Microsoft"

touch "$state_dir/claude.json" "$state_dir/shell/zsh_history"
ln -sfn "$state_dir/claude.json" "$HOME/.claude.json"
ln -sfn "$state_dir/shell/zsh_history" "$HOME/.zsh_history"

/opt/workbench/dotfiles/install.sh
git config --global worktree.useRelativePaths true

echo "workbench: ready"
