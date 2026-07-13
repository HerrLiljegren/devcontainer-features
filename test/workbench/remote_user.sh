#!/bin/bash
set -e

source dev-container-features-test-lib

check_version() {
    command_name="$1"
    expected_version="$2"

    check "$command_name is on PATH" bash -c "command -v '$command_name'"
    check "$command_name has useful version output" bash -c \
        "'$command_name' --version 2>&1 | grep -F '$expected_version'"
}

check_version codex "0.144.3"
check_version claude "2.1.197"
check_version pi "0.80.6"
check_version wt "0.67.0"
check_version glow "2.1.2"
check_version fd "10.4.2"
check_version rg "15.1.0"

reportResults
