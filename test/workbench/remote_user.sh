#!/bin/bash
set -e

source dev-container-features-test-lib
source /opt/workbench/versions.env

check_version() {
    command_name="$1"
    expected_version="$2"

    check "$command_name is on PATH" bash -c "command -v '$command_name'"
    check "$command_name has expected version" bash -c \
        "'$command_name' --version 2>&1 | grep -F '$expected_version'"
}

check_version codex "$CODEX_VERSION"
check_version claude "${CLAUDE_VERSION%-*}"
check_version hunk "$HUNK_VERSION"
check_version opencode "$OPENCODE_VERSION"
check_version wt "$WORKTRUNK_VERSION"
check_version fd "$FD_VERSION"
check_version rg "$RIPGREP_VERSION"
check_version lazygit "$LAZYGIT_VERSION"
check_version jq "jq-"
check_version yq "$YQ_VERSION"
check_version bat "$BAT_VERSION"
check_version delta "$DELTA_VERSION"
check_version eza "$EZA_VERSION"
check_version nvim "$NVIM_VERSION"
check_version zsh "zsh 5."
check_version gh "$GH_VERSION"
check_version fzf "$FZF_VERSION"
check_version zoxide "$ZOXIDE_VERSION"
check_version starship "$STARSHIP_VERSION"
check_version git "2.55.0"
check_version node "v24.18.0"
check_version python3 "Python 3."
check_version shellcheck "version:"

check "Azure DevOps MCP is installed" bash -c \
    "command -v mcp-server-azuredevops"
check "Azure Artifacts credential provider is installed" test -x \
    /opt/workbench/nuget/plugins/netcore/CredentialProvider.Microsoft/CredentialProvider.Microsoft
check "Python venv support is available" bash -c \
    'venv_dir="$(mktemp -d)"; trap '\''rm -rf "$venv_dir"'\'' EXIT; python3 -m venv "$venv_dir/venv"; "$venv_dir/venv/bin/python" -m pip --version'
check "dotfiles are pinned in the image" test -x \
    /opt/workbench/dotfiles/install.sh
check "removed commands are absent" bash -c \
    '! command -v pi && ! command -v glow && ! command -v herdr && ! command -v yamllint'

check "scenario runs as vscode" bash -c \
    'test "$(id -un)" = vscode'
check "Zsh is the login shell" bash -c \
    'test "$(getent passwd "$(id -un)" | cut -d: -f7)" = /bin/zsh'
check "Codex state is persistent" bash -c \
    'test "$(readlink "$HOME/.codex")" = /workbench-state/codex'
check "curated Matt Pocock skills are available to Codex" bash -c \
    'for skill in code-review codebase-design diagnosing-bugs domain-modeling grill-me grill-with-docs grilling handoff implement improve-codebase-architecture prototype research resolving-merge-conflicts tdd to-spec to-tickets triage wayfinder wizard writing-for-agents; do
        test "$(readlink "$CODEX_HOME/skills/$skill")" = "/opt/workbench/skills/mattpocock/$skill" || exit 1
    done'
check "Claude state is persistent" bash -c \
    'test "$(readlink "$HOME/.claude")" = /workbench-state/claude'
check "OpenCode state is persistent" bash -c \
    'test "$(readlink "$HOME/.local/share/opencode")" = /workbench-state/opencode'
check "shell history is persistent" bash -c \
    'test "$(readlink "$HOME/.zsh_history")" = /workbench-state/shell/zsh_history'
check "bootstrap repairs remapped state ownership" bash -c \
    'sudo chown -R root:root /workbench-state &&
     /usr/local/bin/workbench-on-create &&
     test -w /workbench-state'
check "NuGet credential provider is linked" bash -c \
    'test -x "$HOME/.nuget/plugins/netcore/CredentialProvider.Microsoft/CredentialProvider.Microsoft"'
check "dotfiles configured Zsh" grep -Fq \
    '# >>> dotfiles:zsh >>>' "$HOME/.zshrc"
check "dotfiles configured Neovim" test -L \
    "$HOME/.config/nvim"
check "relative Git worktrees are enabled" bash -c \
    'test "$(git config --global --get worktree.useRelativePaths)" = true'
check "login Zsh loads the workbench" zsh -lic \
    'command -v starship >/dev/null && command -v wt >/dev/null && command -v nvim >/dev/null'

reportResults
