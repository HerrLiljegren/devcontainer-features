#!/bin/bash
set -e

source dev-container-features-test-lib

check "scenario runs as vscode" bash -c \
    'test "$(id -un)" = vscode'
check "Zsh is the login shell" bash -c \
    'test "$(getent passwd "$(id -un)" | cut -d: -f7)" = /bin/zsh'
check "Codex state is persistent" bash -c \
    'test "$(readlink "$HOME/.codex")" = /workbench-state/codex'
check "Claude state is persistent" bash -c \
    'test "$(readlink "$HOME/.claude")" = /workbench-state/claude'
check "OpenCode state is persistent" bash -c \
    'test "$(readlink "$HOME/.local/share/opencode")" = /workbench-state/opencode'
check "shell history is persistent" bash -c \
    'test "$(readlink "$HOME/.zsh_history")" = /workbench-state/shell/zsh_history'
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
