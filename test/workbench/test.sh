#!/bin/bash
set -e

source dev-container-features-test-lib

check_version() {
    command_name="$1"
    expected_version="$2"

    check "$command_name is on PATH" bash -c "command -v '$command_name'"
    check "$command_name has expected version" bash -c \
        "'$command_name' --version 2>&1 | grep -F '$expected_version'"
}

check_version codex "0.144.3"
check_version claude "2.1.197"
check_version hunk "0.17.0"
check_version opencode "1.18.5"
check_version wt "0.67.0"
check_version fd "10.4.2"
check_version rg "15.1.0"
check_version lazygit "0.63.0"
check_version jq "jq-"
check_version yq "4.53.3"
check_version bat "0.26.1"
check_version delta "0.19.2"
check_version eza "0.23.5"
check_version nvim "0.12.4"
check_version zsh "zsh 5."
check_version gh "2.96.0"
check_version fzf "0.74.0"
check_version zoxide "0.10.0"
check_version starship "1.26.0"
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

reportResults
