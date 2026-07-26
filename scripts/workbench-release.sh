#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
feature_dir="$repo_root/src/workbench"
versions_file="$feature_dir/versions.env"
checksums_file="$feature_dir/checksums.env"
manifest_file="$feature_dir/update-manifest.tsv"
feature_metadata="$feature_dir/devcontainer-feature.json"
transaction_dir=""
transaction_active=0

# shellcheck disable=SC1091
. "$versions_file"
# shellcheck disable=SC1091
. "$checksums_file"

usage() {
    cat <<'EOF'
Usage:
  scripts/workbench-release.sh check
  scripts/workbench-release.sh update --level patch|minor|major [--apply]
  scripts/workbench-release.sh release --level patch|minor|major [--base X.Y] [--apply]
      [--commit] [--tag] [--push] [--publish]

The default is a dry run. --apply writes pins, checksums, and Feature metadata.
Commit, tag, push, and publish are opt-in flags for the release command.

Update levels mean:
  patch  latest patch in the current major/minor line
  minor  latest minor/patch in the current major line
  major  latest stable major/minor/patch
EOF
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

curl_to_file() {
    local url="$1" destination="$2"
    curl -fsSL --retry 3 -o "$destination" "$url" \
        || die "download failed: $url"
}

github_releases() {
    local repository="$1"
    if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
        gh api "repos/$repository/releases?per_page=100"
        return
    fi
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        curl -fsSL --retry 3 \
            -H 'Accept: application/vnd.github+json' \
            -H "Authorization: Bearer $GITHUB_TOKEN" \
            "https://api.github.com/repos/$repository/releases?per_page=100"
        return
    fi
    die "GitHub API authentication required for $repository; run 'gh auth login' or set GITHUB_TOKEN"
}

begin_transaction() {
    (( apply_changes )) || return 0
    transaction_dir="$(mktemp -d)"
    cp "$versions_file" "$transaction_dir/versions.env"
    cp "$checksums_file" "$transaction_dir/checksums.env"
    cp "$feature_metadata" "$transaction_dir/devcontainer-feature.json"
    transaction_active=1
}

finish_transaction() {
    transaction_active=0
    if [[ -n "$transaction_dir" ]]; then
        rm -rf "$transaction_dir"
        transaction_dir=""
    fi
}

rollback_transaction() {
    local exit_code=$?
    if (( transaction_active )); then
        cp "$transaction_dir/versions.env" "$versions_file"
        cp "$transaction_dir/checksums.env" "$checksums_file"
        cp "$transaction_dir/devcontainer-feature.json" "$feature_metadata"
        printf 'Rolled back partial release changes.\n' >&2
    fi
    if [[ -n "$transaction_dir" ]]; then
        rm -rf "$transaction_dir"
    fi
    trap - EXIT
    exit "$exit_code"
}

trap rollback_transaction EXIT

version_key() {
    local value="${1#v}"
    value="${value%%-*}"
    [[ "$value" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
    printf '%s\n' "$value"
}

version_gt() {
    [[ "$1" != "$2" && "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n1)" == "$1" ]]
}

eligible_version() {
    local current_key candidate_key current_major current_minor candidate_major candidate_minor
    current_key="$(version_key "$1")" || return 1
    candidate_key="$(version_key "$2")" || return 1
    current_major="${current_key%%.*}"
    current_minor="${current_key#*.}"; current_minor="${current_minor%%.*}"
    candidate_major="${candidate_key%%.*}"
    candidate_minor="${candidate_key#*.}"; candidate_minor="${candidate_minor%%.*}"
    version_gt "$candidate_key" "$current_key" || return 1
    case "$3" in
        patch) [[ "$candidate_major" == "$current_major" && "$candidate_minor" == "$current_minor" ]] ;;
        minor) [[ "$candidate_major" == "$current_major" ]] ;;
        major) return 0 ;;
        *) die "unknown update level: $3" ;;
    esac
}

select_best() {
    local current="$1" level="$2" candidates="$3" candidate best=""
    while IFS= read -r candidate; do
        [[ -n "$candidate" ]] || continue
        if eligible_version "$current" "$candidate" "$level"; then
            if [[ -z "$best" ]] || version_gt "$(version_key "$candidate")" "$(version_key "$best")"; then
                best="$candidate"
            fi
        fi
    done <<< "$candidates"
    [[ -n "$best" ]] && printf '%s\n' "$best"
}

env_value() {
    local name="$1"
    [[ "$name" =~ ^[A-Z0-9_]+$ ]] || die "invalid environment variable name: $name"
    printf '%s\n' "${!name:-}"
}

set_env_value() {
    local file="$1" name="$2" value="$3" temp
    temp="$(mktemp)"
    awk -v key="$name" -v value="$value" '
        index($0, key "=") == 1 { print key "=\"" value "\""; found = 1; next }
        { print }
        END { if (!found) exit 1 }
    ' "$file" > "$temp" || { rm -f "$temp"; die "pin not found: $name in $file"; }
    if (( apply_changes )); then
        mv "$temp" "$file"
    else
        rm -f "$temp"
    fi
}

set_feature_version() {
    local value="$1" temp
    temp="$(mktemp)"
    jq --arg version "$value" '.version = $version' "$feature_metadata" > "$temp"
    if (( apply_changes )); then
        mv "$temp" "$feature_metadata"
    else
        rm -f "$temp"
    fi
}

show_change() {
    printf '  %s: %s -> %s\n' "$1" "$2" "$3"
}

latest_npm() {
    npm view "$1" versions --json | jq -r 'if type == "array" then .[] else . end' \
        | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$'
}

latest_github() {
    local repository="$1" prefix="$2" response temp
    temp="$(mktemp)"
    github_releases "$repository" > "$temp"
    response="$(<"$temp")"
    rm -f "$temp"
    jq -r --arg prefix "$prefix" '
        .[] | select(.draft | not) | select(.prerelease | not) | .tag_name
        | select(startswith($prefix))
        | if $prefix == "" then . else ltrimstr($prefix) end
    ' <<< "$response" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$'
}

asset_sha256() {
    local repository="$1" tag="$2" asset="$3" temp
    temp="$(mktemp)"
    curl_to_file "https://github.com/$repository/releases/download/$tag/$asset" "$temp"
    sha256sum "$temp" | awk '{print $1}'
    rm -f "$temp"
}

url_sha256() {
    local url="$1" temp
    temp="$(mktemp)"
    curl_to_file "$url" "$temp"
    sha256sum "$temp" | awk '{print $1}'
    rm -f "$temp"
}

update_dotfiles() {
    local commit archive sha current
    commit="$(git ls-remote https://github.com/HerrLiljegren/dotfiles.git refs/heads/main | awk 'NR == 1 {print $1}')"
    [[ "$commit" =~ ^[0-9a-f]{40}$ ]] || die "could not resolve dotfiles main"
    archive="$(mktemp)"
    curl_to_file "https://github.com/HerrLiljegren/dotfiles/archive/$commit.tar.gz" "$archive"
    sha="$(sha256sum "$archive" | awk '{print $1}')"
    rm -f "$archive"
    current="$(env_value DOTFILES_COMMIT)"
    if [[ "$commit" != "$current" ]]; then
        show_change DOTFILES_COMMIT "$current" "$commit"
        set_env_value "$versions_file" DOTFILES_COMMIT "$commit"
    fi
    current="$(env_value DOTFILES_SHA256)"
    if [[ "$sha" != "$current" ]]; then
        show_change DOTFILES_SHA256 "$current" "$sha"
        set_env_value "$versions_file" DOTFILES_SHA256 "$sha"
    fi
}

update_npm_package() {
    local name="$1" variable="$2" package="$3" level="$4" current candidates next
    current="$(env_value "$variable")"
    candidates="$(latest_npm "$package")"
    next="$(select_best "$current" "$level" "$candidates" || true)"
    if [[ -n "$next" ]]; then
        show_change "$name" "$current" "$next"
        set_env_value "$versions_file" "$variable" "$next"
        printf -v "$variable" '%s' "$next"
    fi
}

update_github_package() {
    local name="$1" variable="$2" repository="$3" prefix="$4" asset_amd64="$5" asset_arm64="$6" checksum_amd64="$7" checksum_arm64="$8" level="$9"
    local current candidates next tag sha
    current="$(env_value "$variable")"
    candidates="$(latest_github "$repository" "$prefix")"
    next="$(select_best "$current" "$level" "$candidates" || true)"
    [[ -n "$next" ]] || return 0
    show_change "$name" "$current" "$next"
    set_env_value "$versions_file" "$variable" "$next"
    printf -v "$variable" '%s' "$next"
    tag="${prefix}${next}"
    sha="$(asset_sha256 "$repository" "$tag" "$(printf "$asset_amd64" "$next")")"
    show_change "$checksum_amd64" "$(env_value "$checksum_amd64")" "$sha"
    set_env_value "$checksums_file" "$checksum_amd64" "$sha"
    sha="$(asset_sha256 "$repository" "$tag" "$(printf "$asset_arm64" "$next")")"
    show_change "$checksum_arm64" "$(env_value "$checksum_arm64")" "$sha"
    set_env_value "$checksums_file" "$checksum_arm64" "$sha"
}

latest_claude() {
    local packages_url='https://downloads.claude.ai/claude-code/apt/stable/dists/stable/main/binary-amd64/Packages'
    local response
    if ! response="$(curl -fsSL --retry 3 "$packages_url")"; then
        response="$(curl -fsSL --retry 3 "$packages_url.gz" | gzip -dc)" \
            || die "could not query Claude's signed apt package index"
    fi
    awk '
        /^Package: claude-code$/ { package = 1; next }
        package && /^Version:/ { print $2; package = 0 }
    ' <<< "$response" | sort -V | uniq
}

update_claude() {
    local level="$1" current candidates next asset sha
    current="$(env_value CLAUDE_VERSION)"
    candidates="$(latest_claude)"
    next="$(select_best "$current" "$level" "$candidates" || true)"
    [[ -n "$next" ]] || return 0
    show_change claude "$current" "$next"
    set_env_value "$versions_file" CLAUDE_VERSION "$next"
    asset="claude-code_${next}_amd64.deb"
    sha="$(url_sha256 "https://downloads.claude.ai/claude-code/apt/stable/pool/main/c/claude-code/$asset")"
    show_change CLAUDE_SHA256_AMD64 "$(env_value CLAUDE_SHA256_AMD64)" "$sha"
    set_env_value "$checksums_file" CLAUDE_SHA256_AMD64 "$sha"
    asset="claude-code_${next}_arm64.deb"
    sha="$(url_sha256 "https://downloads.claude.ai/claude-code/apt/stable/pool/main/c/claude-code/$asset")"
    show_change CLAUDE_SHA256_ARM64 "$(env_value CLAUDE_SHA256_ARM64)" "$sha"
    set_env_value "$checksums_file" CLAUDE_SHA256_ARM64 "$sha"
}

latest_feature() {
    local feature="$1" temp
    temp="$(mktemp)"
    curl_to_file \
        "https://raw.githubusercontent.com/devcontainers/features/main/src/$feature/devcontainer-feature.json" \
        "$temp"
    jq -r '.version' "$temp"
    rm -f "$temp"
}

set_feature_dependency_version() {
    local feature="$1" value="$2" temp
    temp="$(mktemp)"
    jq --arg feature "$feature" --arg version "$value" '
        .dependsOn |= with_entries(
            if (.key | startswith("ghcr.io/devcontainers/features/" + $feature + ":"))
            then .key = ("ghcr.io/devcontainers/features/" + $feature + ":" + $version)
            else .
            end)
    ' "$feature_metadata" > "$temp"
    if (( apply_changes )); then
        mv "$temp" "$feature_metadata"
    else
        rm -f "$temp"
    fi
}

update_feature_dependency() {
    local feature="$1" level="$2" current candidates next
    current="$(jq -r --arg feature "$feature" '
        .dependsOn | to_entries[]
        | select(.key | startswith("ghcr.io/devcontainers/features/" + $feature + ":"))
        | .key | split(":")[-1]
    ' "$feature_metadata")"
    candidates="$(latest_feature "$feature")"
    next="$(select_best "$current" "$level" "$candidates" || true)"
    if [[ -n "$next" ]]; then
        show_change "feature-$feature" "$current" "$next"
        set_feature_dependency_version "$feature" "$next"
    fi
}

check_pins() {
    local name kind variable source prefix asset_amd64 asset_arm64 checksum_amd64 checksum_arm64
    while IFS='|' read -r name kind variable source prefix asset_amd64 asset_arm64 checksum_amd64 checksum_arm64; do
        [[ -z "$name" || "$name" == \#* ]] && continue
        case "$kind" in
            npm|github|apt)
                [[ -n "${!variable:-}" ]] || die "empty version pin: $variable"
                ;;
            feature) ;;
            *) die "unknown update kind '$kind' for '$name'" ;;
        esac
    done < "$manifest_file"
    while IFS='=' read -r name _; do
        [[ -z "$name" || "$name" == \#* ]] && continue
        [[ -n "${!name:-}" ]] || die "empty checksum pin: $name"
    done < "$checksums_file"
    [[ "${#DOTFILES_COMMIT}" -eq 40 ]] || die 'invalid DOTFILES_COMMIT pin'
    [[ "${#DOTFILES_SHA256}" -eq 64 ]] || die 'invalid DOTFILES_SHA256 pin'
    printf 'Workbench pin manifests are complete.\n'
}

update_packages() {
    local level="$1" name kind variable source prefix asset_amd64 asset_arm64 checksum_amd64 checksum_arm64
    require_command gzip
    while IFS='|' read -r name kind variable source prefix asset_amd64 asset_arm64 checksum_amd64 checksum_arm64; do
        [[ -z "$name" || "$name" == \#* ]] && continue
        case "$kind" in
            npm) update_npm_package "$name" "$variable" "$source" "$level" ;;
            github) update_github_package "$name" "$variable" "$source" "$prefix" "$asset_amd64" "$asset_arm64" "$checksum_amd64" "$checksum_arm64" "$level" ;;
            apt) update_claude "$level" ;;
            feature) update_feature_dependency "$variable" "$level" ;;
            *) die "unknown update kind '$kind' for '$name'" ;;
        esac
    done < "$manifest_file"
}

next_feature_version() {
    local base="$1" current latest patch
    current="$(jq -r '.version' "$feature_metadata")"
    latest="$(git tag --list "v${base}.*" --sort=-v:refname | head -n1 || true)"
    if [[ -z "$latest" ]]; then
        printf '%s\n' "$current"
        return
    fi
    patch="${latest##*.}"
    printf '%s.%s\n' "$base" "$((patch + 1))"
}

apply_changes=0
commit_changes=0
tag_release=0
push_changes=0
publish_release=0
command_name=""
level=""
base=""
while (($#)); do
    case "$1" in
        check|update|release) command_name="$1"; shift ;;
        --level) level="${2:?missing value for --level}"; shift 2 ;;
        --base) base="${2:?missing value for --base}"; shift 2 ;;
        --apply) apply_changes=1; shift ;;
        --commit) commit_changes=1; shift ;;
        --tag) tag_release=1; shift ;;
        --push) push_changes=1; shift ;;
        --publish) publish_release=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "unknown argument: $1" ;;
    esac
done

[[ -n "$command_name" ]] || { usage >&2; exit 2; }
if [[ "$command_name" == check ]]; then
    check_pins
    exit 0
fi
[[ "$level" =~ ^(patch|minor|major)$ ]] || die "--level must be patch, minor, or major"
[[ "$command_name" == release || $commit_changes -eq 0 ]] || die "--commit is only valid for release"
[[ "$command_name" == release || $tag_release -eq 0 ]] || die "--tag is only valid for release"
[[ "$command_name" == release || $push_changes -eq 0 ]] || die "--push is only valid for release"
[[ "$command_name" == release || $publish_release -eq 0 ]] || die "--publish is only valid for release"
(( ! commit_changes || apply_changes )) || die "--commit requires --apply"
(( ! tag_release || commit_changes )) || die "--tag requires --commit"
(( ! push_changes || tag_release )) || die "--push requires --tag"
(( ! publish_release || push_changes )) || die "--publish requires --push"
if [[ "$command_name" == release ]]; then
    [[ -z "$base" || "$base" =~ ^[0-9]+\.[0-9]+$ ]] || die "--base must be X.Y"
    base="${base:-$(jq -r '.version' "$feature_metadata" | cut -d. -f1-2)}"
fi

printf 'Workbench %s (%s mode)\n' "$command_name" "$([[ $apply_changes -eq 1 ]] && echo apply || echo dry-run)"
begin_transaction
update_dotfiles
update_packages "$level"
if [[ "$command_name" == release ]]; then
    release_version="$(next_feature_version "$base")"
    current="$(jq -r '.version' "$feature_metadata")"
    if [[ "$release_version" != "$current" ]]; then
        show_change feature-version "$current" "$release_version"
        set_feature_version "$release_version"
    fi
    printf '  release tag: v%s\n' "$release_version"
fi

if (( ! apply_changes )); then
    printf '%s\n' 'Dry run only. Re-run with --apply to write these changes.'
fi

if (( apply_changes && commit_changes )); then
    git add src/workbench/versions.env src/workbench/checksums.env src/workbench/devcontainer-feature.json
    git diff --cached --quiet && die 'no release changes to commit'
    git commit -m "chore(workbench): release v$release_version"
    finish_transaction
else
    finish_transaction
fi

if (( apply_changes && tag_release )); then
    git tag "v$release_version"
fi

if (( apply_changes && push_changes )); then
    branch="$(git branch --show-current)"
    [[ "$branch" == main ]] || die "--push requires the main branch (current: ${branch:-detached})"
    git push origin "HEAD:$branch" "v$release_version"
fi

if (( apply_changes && publish_release )); then
    require_command gh
    gh workflow run release.yaml --ref main
    printf '  release workflow dispatched\n'
fi
