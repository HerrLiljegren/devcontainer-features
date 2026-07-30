#!/usr/bin/env bash
set -euo pipefail

test_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
skill_dir="$(CDPATH= cd -- "$test_dir/.." && pwd)"
repo_root="$(git -C "$skill_dir" rev-parse --show-toplevel)"
# shellcheck source=../scripts/lib.sh
. "$skill_dir/scripts/lib.sh"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

assert_eq() {
    [[ "$1" == "$2" ]] || fail "expected '$2', got '$1'"
}

assert_match() {
    grep -Fq -- "$2" <<< "$1" || fail "missing '$2'"
}

test_versions() {
    local candidates
    candidates=$'1.2.4\n1.3.0\n2.0.0\n1.2.5-beta'
    assert_eq "$(select_best 1.2.3 patch "$candidates")" 1.2.4
    assert_eq "$(select_best 1.2.3 minor "$candidates")" 1.3.0
    assert_eq "$(select_best 1.2.3 major "$candidates")" 2.0.0
    assert_eq "$(next_feature_version 2.1.3 patch)" 2.1.4
    assert_eq "$(next_feature_version 2.1.3 minor)" 2.1.4
    assert_eq "$(next_feature_version 2.1.3 major)" 2.2.0
}

test_state_classification() {
    assert_eq "$(classify_release_state a 2.2.0 2.2.0 '' false '' '' '' '')" ready
    assert_eq "$(classify_release_state a 2.2.0 2.2.0 a true sha256:x completed success success)" complete
    assert_eq "$(classify_release_state a 2.2.0 2.2.0 '' false sha256:x completed failure success)" resume-release
    assert_eq "$(classify_release_state a 2.2.0 2.2.0 b false '' completed failure failure)" conflict
    assert_eq "$(classify_release_state a 2.1.0 2.2.0 '' false '' '' '' '')" conflict
}

test_inventory() {
    local manifest="$repo_root/src/workbench/update-manifest.tsv"
    local versions="$repo_root/src/workbench/versions.env"
    local checksums="$repo_root/src/workbench/checksums.env"
    local metadata="$repo_root/src/workbench/devcontainer-feature.json"
    local key

    while IFS= read -r key; do
        awk -F '|' -v key="$key" '
            $1 !~ /^#/ && ($3 == key || $8 == key || $9 == key) { found = 1 }
            END { exit !found }
        ' "$manifest" || fail "version pin is absent from update manifest: $key"
    done < <(awk -F= '/^[A-Z0-9_]+=/ { print $1 }' "$versions")

    while IFS= read -r key; do
        awk -F '|' -v key="$key" '
            $1 !~ /^#/ && ($8 == key || $9 == key) { found = 1 }
            END { exit !found }
        ' "$manifest" || fail "checksum pin is absent from update manifest: $key"
    done < <(awk -F= '/^[A-Z0-9_]+=/ { print $1 }' "$checksums")

    while IFS= read -r key; do
        awk -F '|' -v key="$key" '
            $1 !~ /^#/ && $2 == "feature" && $3 == key { found = 1 }
            END { exit !found }
        ' "$manifest" || fail "Feature dependency is absent from update manifest: $key"
    done < <(jq -r '.dependsOn | keys[] | split("/")[-1] | split(":")[0]' "$metadata")

    duplicates="$(awk -F '|' '
        $1 !~ /^#/ && $1 != "" { count[$1]++ }
        END { for (name in count) if (count[name] > 1) print name }
    ' "$manifest")"
    [[ -z "$duplicates" ]] || fail "duplicate update manifest names: $duplicates"
}

test_release_notes() {
    local fixture output
    fixture="$(mktemp -d)"
    git -C "$fixture" init -q
    git -C "$fixture" config user.name test
    git -C "$fixture" config user.email test@example.invalid
    mkdir -p "$fixture/src/workbench"

    printf '%s\n' \
        'TOOL_VERSION="1.2.3"' \
        'DOTFILES_COMMIT="1111111111111111111111111111111111111111"' \
        'DOTFILES_SHA256="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"' \
        > "$fixture/src/workbench/versions.env"
    printf '%s\n' \
        '# name|kind|version variable|source-specific fields...' \
        'tool|npm|TOOL_VERSION|example' \
        'dotfiles|git|DOTFILES_COMMIT|owner/repo||||DOTFILES_SHA256|' \
        > "$fixture/src/workbench/update-manifest.tsv"
    printf '%s\n' \
        '{"version":"2.1.0","dependsOn":{"ghcr.io/devcontainers/features/git:1.0.0":{}}}' \
        > "$fixture/src/workbench/devcontainer-feature.json"
    git -C "$fixture" add .
    git -C "$fixture" commit -qm initial
    git -C "$fixture" tag v2.1.0

    sed -i 's/1.2.3/1.3.0/' "$fixture/src/workbench/versions.env"
    sed -i 's/111111111111/222222222222/' "$fixture/src/workbench/versions.env"
    sed -i 's/2.1.0/2.1.1/; s/git:1.0.0/git:1.1.0/' "$fixture/src/workbench/devcontainer-feature.json"
    git -C "$fixture" add .
    git -C "$fixture" commit -qm update

    output="$(WORKBENCH_REPO_ROOT="$fixture" "$skill_dir/scripts/release-notes.sh" v2.1.0 HEAD)"
    assert_match "$output" 'Workbench: `2.1.0` -> `2.1.1`'
    assert_match "$output" '`tool`: `1.2.3` -> `1.3.0`'
    assert_match "$output" '`git`: `1.0.0` -> `1.1.0`'
    assert_match "$output" '`dotfiles`: `111111111111` -> `222222222222`'
    rm -rf "$fixture"
}

test_versions
test_state_classification
test_inventory
test_release_notes
printf 'release-workbench tests: ok\n'
