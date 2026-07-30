#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="${WORKBENCH_REPO_ROOT:-$(git -C "$script_dir" rev-parse --show-toplevel)}"
from_ref="${1:-}"
to_ref="${2:-WORKTREE}"

if [[ -z "$from_ref" || $# -gt 2 ]]; then
    printf 'Usage: %s FROM_REF [TO_REF|WORKTREE]\n' "${0##*/}" >&2
    exit 2
fi

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

read_path() {
    local ref="$1" path="$2" destination="$3"
    if [[ "$ref" == WORKTREE ]]; then
        cp "$repo_root/$path" "$destination"
    else
        git -C "$repo_root" show "$ref:$path" > "$destination"
    fi
}

env_value() {
    local file="$1" key="$2"
    awk -F= -v key="$key" '
        $1 == key {
            value = substr($0, index($0, "=") + 1)
            gsub(/^"|"$/, "", value)
            print value
            found = 1
            exit
        }
        END { if (!found) exit 1 }
    ' "$file"
}

dependency_versions() {
    jq -r '
        .dependsOn
        | keys[]
        | capture("^ghcr\\.io/devcontainers/features/(?<name>[^:]+):(?<version>.+)$")
        | [.name, .version]
        | @tsv
    ' "$1"
}

read_path "$from_ref" src/workbench/versions.env "$work_dir/from-versions.env"
read_path "$from_ref" src/workbench/devcontainer-feature.json "$work_dir/from-feature.json"
read_path "$to_ref" src/workbench/versions.env "$work_dir/to-versions.env"
read_path "$to_ref" src/workbench/devcontainer-feature.json "$work_dir/to-feature.json"
read_path "$to_ref" src/workbench/update-manifest.tsv "$work_dir/to-manifest.tsv"

from_version="$(jq -r .version "$work_dir/from-feature.json")"
to_version="$(jq -r .version "$work_dir/to-feature.json")"

printf '## Workbench changes\n\n'
printf -- '- Workbench: `%s` -> `%s`\n' "$from_version" "$to_version"

tool_notes="$work_dir/tool-notes.md"
dotfiles_notes="$work_dir/dotfiles-notes.md"
: > "$tool_notes"
: > "$dotfiles_notes"

while IFS='|' read -r name kind variable _source _prefix _amd64_asset _arm64_asset _amd64_checksum _arm64_checksum; do
    [[ -z "$name" || "$name" == \#* || "$kind" == feature ]] && continue
    old="$(env_value "$work_dir/from-versions.env" "$variable" 2>/dev/null || printf '(not pinned)')"
    new="$(env_value "$work_dir/to-versions.env" "$variable")"
    [[ "$old" != "$new" ]] || continue

    [[ "$kind" == git ]] && continue
    printf -- '- `%s`: `%s` -> `%s`\n' "$name" "$old" "$new" >> "$tool_notes"
done < "$work_dir/to-manifest.tsv"

old_dotfiles="$(env_value "$work_dir/from-versions.env" DOTFILES_COMMIT)"
new_dotfiles="$(env_value "$work_dir/to-versions.env" DOTFILES_COMMIT)"
if [[ "$old_dotfiles" != "$new_dotfiles" ]]; then
    printf -- '- `dotfiles`: `%s` -> `%s`\n' \
        "${old_dotfiles:0:12}" \
        "${new_dotfiles:0:12}" \
        > "$dotfiles_notes"
fi

if [[ -s "$tool_notes" ]]; then
    printf '\n### Tool updates\n\n'
    cat "$tool_notes"
fi

dependency_versions "$work_dir/from-feature.json" > "$work_dir/from-dependencies.tsv"
dependency_versions "$work_dir/to-feature.json" > "$work_dir/to-dependencies.tsv"
cut -f1 "$work_dir/from-dependencies.tsv" "$work_dir/to-dependencies.tsv" | sort -u > "$work_dir/dependency-names"

dependency_notes="$work_dir/dependency-notes.md"
: > "$dependency_notes"
while IFS= read -r name; do
    old="$(awk -F '\t' -v name="$name" '$1 == name { print $2 }' "$work_dir/from-dependencies.tsv")"
    new="$(awk -F '\t' -v name="$name" '$1 == name { print $2 }' "$work_dir/to-dependencies.tsv")"
    [[ "$old" != "$new" ]] || continue
    printf -- '- `%s`: `%s` -> `%s`\n' "$name" "${old:-(not present)}" "${new:-(removed)}" >> "$dependency_notes"
done < "$work_dir/dependency-names"

if [[ -s "$dependency_notes" ]]; then
    printf '\n### Feature dependencies\n\n'
    cat "$dependency_notes"
fi

if [[ -s "$dotfiles_notes" ]]; then
    printf '\n### Public dotfiles\n\n'
    cat "$dotfiles_notes"
fi
