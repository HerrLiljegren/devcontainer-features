#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="${WORKBENCH_REPO_ROOT:-$(git -C "$script_dir" rev-parse --show-toplevel)}"
# shellcheck source=lib.sh
. "$script_dir/lib.sh"
feature_dir="$repo_root/src/workbench"
source_versions="$feature_dir/versions.env"
source_checksums="$feature_dir/checksums.env"
source_metadata="$feature_dir/devcontainer-feature.json"
manifest="$feature_dir/update-manifest.tsv"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

versions="$work_dir/versions.env"
checksums="$work_dir/checksums.env"
metadata="$work_dir/devcontainer-feature.json"
cp "$source_versions" "$versions"
cp "$source_checksums" "$checksums"
cp "$source_metadata" "$metadata"

# shellcheck disable=SC1090
. "$versions"
# shellcheck disable=SC1090
. "$checksums"

usage() {
    printf 'Usage: %s patch|minor|major [--apply]\n' "${0##*/}"
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

level="${1:-}"
[[ "$level" =~ ^(patch|minor|major)$ ]] || { usage >&2; exit 2; }
case "${2:-}" in
    "") apply=0 ;;
    --apply) apply=1 ;;
    *) usage >&2; exit 2 ;;
esac
(( $# <= 2 )) || { usage >&2; exit 2; }

for command_name in curl gh git jq npm sha256sum; do
    require_command "$command_name"
done
gh auth status -h github.com >/dev/null 2>&1 \
    || die "GitHub CLI is not authenticated; run 'gh auth login -h github.com'"

pin_value() {
    local name="$1"
    [[ "$name" =~ ^[A-Z0-9_]+$ ]] || die "invalid pin name: $name"
    printf '%s\n' "${!name:-}"
}

set_pin() {
    local file="$1" name="$2" value="$3" temp
    temp="$(mktemp)"
    awk -v key="$name" -v value="$value" '
        index($0, key "=") == 1 { print key "=\"" value "\""; found = 1; next }
        { print }
        END { if (!found) exit 1 }
    ' "$file" > "$temp" || { rm -f "$temp"; die "pin not found: $name"; }
    mv "$temp" "$file"
    printf -v "$name" '%s' "$value"
}

show_change() {
    printf '  %s: %s -> %s\n' "$1" "$2" "$3"
}

download_sha256() {
    local url="$1" temp
    temp="$(mktemp)"
    curl -fsSL --retry 3 -o "$temp" "$url" || die "download failed: $url"
    sha256sum "$temp" | awk '{print $1}'
    rm -f "$temp"
}

latest_npm() {
    npm view "$1" versions --json \
        | jq -r 'if type == "array" then .[] else . end' \
        | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$'
}

latest_github() {
    local repository="$1" prefix="$2"
    gh api "repos/$repository/releases?per_page=100" \
        | jq -r --arg prefix "$prefix" '
            .[]
            | select(.draft | not)
            | select(.prerelease | not)
            | .tag_name
            | select(startswith($prefix))
            | if $prefix == "" then . else ltrimstr($prefix) end
        ' \
        | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$'
}

update_dotfiles() {
    local variable="$1" repository="$2" checksum="$3" commit sha current
    commit="$(gh api "repos/$repository/commits/main" --jq .sha)"
    [[ "$commit" =~ ^[0-9a-f]{40}$ ]] || die "could not resolve dotfiles main"
    sha="$(download_sha256 "https://github.com/$repository/archive/$commit.tar.gz")"

    current="$(pin_value "$variable")"
    if [[ "$commit" != "$current" ]]; then
        show_change "$variable" "$current" "$commit"
        set_pin "$versions" "$variable" "$commit"
    fi
    current="$(pin_value "$checksum")"
    if [[ "$sha" != "$current" ]]; then
        show_change "$checksum" "$current" "$sha"
        set_pin "$versions" "$checksum" "$sha"
    fi
}

update_npm() {
    local name="$1" variable="$2" package="$3" current next
    current="$(pin_value "$variable")"
    next="$(select_best "$current" "$level" "$(latest_npm "$package")" || true)"
    [[ -n "$next" ]] || return 0
    show_change "$name" "$current" "$next"
    set_pin "$versions" "$variable" "$next"
}

update_github() {
    local name="$1" variable="$2" repository="$3" prefix="$4"
    local amd64_asset="$5" arm64_asset="$6" amd64_checksum="$7" arm64_checksum="$8"
    local current next tag sha
    current="$(pin_value "$variable")"
    next="$(select_best "$current" "$level" "$(latest_github "$repository" "$prefix")" || true)"
    [[ -n "$next" ]] || return 0

    show_change "$name" "$current" "$next"
    set_pin "$versions" "$variable" "$next"
    tag="${prefix}${next}"

    sha="$(download_sha256 "https://github.com/$repository/releases/download/$tag/$(printf "$amd64_asset" "$next")")"
    show_change "$amd64_checksum" "$(pin_value "$amd64_checksum")" "$sha"
    set_pin "$checksums" "$amd64_checksum" "$sha"

    sha="$(download_sha256 "https://github.com/$repository/releases/download/$tag/$(printf "$arm64_asset" "$next")")"
    show_change "$arm64_checksum" "$(pin_value "$arm64_checksum")" "$sha"
    set_pin "$checksums" "$arm64_checksum" "$sha"
}

latest_claude() {
    curl -fsSL --retry 3 \
        https://downloads.claude.ai/claude-code/apt/stable/dists/stable/main/binary-amd64/Packages \
        | awk '
            /^Package: claude-code$/ { package = 1; next }
            package && /^Version:/ { print $2; package = 0 }
        ' \
        | sort -V \
        | uniq
}

update_claude() {
    local variable="$1" amd64_checksum="$2" arm64_checksum="$3"
    local current next asset sha
    current="$(pin_value "$variable")"
    next="$(select_best "$current" "$level" "$(latest_claude)" || true)"
    [[ -n "$next" ]] || return 0

    show_change claude "$current" "$next"
    set_pin "$versions" "$variable" "$next"

    asset="claude-code_${next}_amd64.deb"
    sha="$(download_sha256 "https://downloads.claude.ai/claude-code/apt/stable/pool/main/c/claude-code/$asset")"
    show_change "$amd64_checksum" "$(pin_value "$amd64_checksum")" "$sha"
    set_pin "$checksums" "$amd64_checksum" "$sha"

    asset="claude-code_${next}_arm64.deb"
    sha="$(download_sha256 "https://downloads.claude.ai/claude-code/apt/stable/pool/main/c/claude-code/$asset")"
    show_change "$arm64_checksum" "$(pin_value "$arm64_checksum")" "$sha"
    set_pin "$checksums" "$arm64_checksum" "$sha"
}

latest_feature() {
    local feature="$1"
    curl -fsSL --retry 3 \
        "https://raw.githubusercontent.com/devcontainers/features/main/src/$feature/devcontainer-feature.json" \
        | jq -r .version
}

update_feature() {
    local feature="$1" current next temp
    current="$(jq -r --arg feature "$feature" '
        .dependsOn
        | keys[]
        | select(startswith("ghcr.io/devcontainers/features/" + $feature + ":"))
        | split(":")[-1]
    ' "$metadata")"
    next="$(select_best "$current" "$level" "$(latest_feature "$feature")" || true)"
    [[ -n "$next" ]] || return 0

    show_change "feature-$feature" "$current" "$next"
    temp="$(mktemp)"
    jq --arg feature "$feature" --arg version "$next" '
        .dependsOn |= with_entries(
            if (.key | startswith("ghcr.io/devcontainers/features/" + $feature + ":"))
            then .key = ("ghcr.io/devcontainers/features/" + $feature + ":" + $version)
            else .
            end
        )
    ' "$metadata" > "$temp"
    mv "$temp" "$metadata"
}

printf 'Workbench update (%s, %s)\n' "$level" "$([[ $apply -eq 1 ]] && printf apply || printf preview)"

while IFS='|' read -r name kind variable source prefix amd64_asset arm64_asset amd64_checksum arm64_checksum; do
    [[ -z "$name" || "$name" == \#* ]] && continue
    case "$kind" in
        npm) update_npm "$name" "$variable" "$source" ;;
        github) update_github "$name" "$variable" "$source" "$prefix" "$amd64_asset" "$arm64_asset" "$amd64_checksum" "$arm64_checksum" ;;
        apt) update_claude "$variable" "$amd64_checksum" "$arm64_checksum" ;;
        feature) update_feature "$variable" ;;
        git) update_dotfiles "$variable" "$source" "$amd64_checksum" ;;
        *) die "unknown update source '$kind' for '$name'" ;;
    esac
done < "$manifest"

if cmp -s "$source_versions" "$versions" \
    && cmp -s "$source_checksums" "$checksums" \
    && cmp -s "$source_metadata" "$metadata"; then
    printf 'Already current.\n'
    exit 0
fi

current_feature_version="$(jq -r .version "$metadata")"
new_feature_version="$(next_feature_version "$current_feature_version" "$level")"
show_change feature-version "$current_feature_version" "$new_feature_version"
temp="$(mktemp)"
jq --arg version "$new_feature_version" '.version = $version' "$metadata" > "$temp"
mv "$temp" "$metadata"

if (( apply )); then
    cp "$versions" "$source_versions"
    cp "$checksums" "$source_checksums"
    cp "$metadata" "$source_metadata"
    printf 'Updated Workbench manifests. Review with git diff.\n'
else
    printf 'Preview only. Re-run with --apply to write these changes.\n'
fi
