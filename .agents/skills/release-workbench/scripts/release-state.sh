#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="${WORKBENCH_REPO_ROOT:-$(git -C "$script_dir" rev-parse --show-toplevel)}"
# shellcheck source=lib.sh
. "$script_dir/lib.sh"

expected_version="${1:-}"
expected_sha="${2:-}"
if [[ ! "$expected_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ || ! "$expected_sha" =~ ^[0-9a-f]{40}$ || $# -ne 2 ]]; then
    printf 'Usage: %s X.Y.Z EXPECTED_SHA\n' "${0##*/}" >&2
    exit 2
fi

for command_name in curl gh git jq; do
    command -v "$command_name" >/dev/null 2>&1 || {
        printf 'error: required command not found: %s\n' "$command_name" >&2
        exit 1
    }
done

repository="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
repository_lc="${repository,,}"
package_repository="${repository_lc}/workbench"
tag="v${expected_version}"
manifest_version="$(jq -r .version "$repo_root/src/workbench/devcontainer-feature.json")"
head_sha="$(git -C "$repo_root" rev-parse HEAD)"
branch="$(git -C "$repo_root" branch --show-current)"
if [[ -z "$(git -C "$repo_root" status --porcelain)" ]]; then
    clean=true
else
    clean=false
fi
origin_main="$(git -C "$repo_root" ls-remote origin refs/heads/main | awk 'NR == 1 { print $1 }')"
tag_sha="$(git -C "$repo_root" ls-remote origin "refs/tags/$tag" "refs/tags/$tag^{}" | awk '
    $2 ~ /\^\{\}$/ { peeled = $1 }
    $2 !~ /\^\{\}$/ { direct = $1 }
    END { print peeled != "" ? peeled : direct }
')"

if release_json="$(gh release view "$tag" --json tagName,url 2>/dev/null)"; then
    release_exists=true
    release_url="$(jq -r .url <<< "$release_json")"
else
    release_exists=false
    release_url=""
fi

package_digest() {
    local alias="$1" token headers status
    token="$(curl -fsSL --get \
        --data-urlencode "scope=repository:${package_repository}:pull" \
        https://ghcr.io/token | jq -r .token)"
    headers="$(mktemp)"
    status="$(curl -sS -o /dev/null -D "$headers" -w '%{http_code}' \
        -H "Authorization: Bearer $token" \
        -H 'Accept: application/vnd.oci.image.manifest.v1+json' \
        "https://ghcr.io/v2/${package_repository}/manifests/${alias}")"
    if [[ "$status" == 200 ]]; then
        awk 'tolower($1) == "docker-content-digest:" { gsub("\r", "", $2); print $2 }' "$headers"
    elif [[ "$status" != 404 ]]; then
        printf 'error: GHCR returned HTTP %s for %s\n' "$status" "$alias" >&2
        rm -f "$headers"
        return 1
    fi
    rm -f "$headers"
}

exact_digest="$(package_digest "$expected_version")"
minor_alias="${expected_version%.*}"
major_alias="${expected_version%%.*}"
minor_digest="$(package_digest "$minor_alias")"
major_digest="$(package_digest "$major_alias")"

workflow_json="$(gh run list \
    --workflow release.yaml \
    --commit "$expected_sha" \
    --event workflow_dispatch \
    --limit 1 \
    --json databaseId,status,conclusion,url \
    --jq '.[0] // {}')"
workflow_id="$(jq -r '.databaseId // empty' <<< "$workflow_json")"
workflow_status="$(jq -r '.status // empty' <<< "$workflow_json")"
workflow_conclusion="$(jq -r '.conclusion // empty' <<< "$workflow_json")"
workflow_url="$(jq -r '.url // empty' <<< "$workflow_json")"
publish_conclusion=""
if [[ -n "$workflow_id" ]]; then
    publish_conclusion="$(gh run view "$workflow_id" --json jobs --jq '
        [.jobs[] | select(.name == "Publish") | .conclusion][0] // ""
    ')"
fi

classification="$(classify_release_state \
    "$expected_sha" \
    "$manifest_version" \
    "$expected_version" \
    "$tag_sha" \
    "$release_exists" \
    "$exact_digest" \
    "$workflow_status" \
    "$workflow_conclusion" \
    "$publish_conclusion")"

jq -n \
    --arg classification "$classification" \
    --arg expected_version "$expected_version" \
    --arg expected_sha "$expected_sha" \
    --arg manifest_version "$manifest_version" \
    --arg head_sha "$head_sha" \
    --arg branch "$branch" \
    --arg origin_main "$origin_main" \
    --arg tag "$tag" \
    --arg tag_sha "$tag_sha" \
    --arg release_url "$release_url" \
    --arg exact_digest "$exact_digest" \
    --arg minor_alias "$minor_alias" \
    --arg minor_digest "$minor_digest" \
    --arg major_alias "$major_alias" \
    --arg major_digest "$major_digest" \
    --arg workflow_id "$workflow_id" \
    --arg workflow_status "$workflow_status" \
    --arg workflow_conclusion "$workflow_conclusion" \
    --arg workflow_url "$workflow_url" \
    --arg publish_conclusion "$publish_conclusion" \
    --argjson clean "$clean" \
    --argjson release_exists "$release_exists" \
    '{
        classification: $classification,
        expected: { version: $expected_version, sha: $expected_sha },
        repository: {
            branch: $branch,
            clean: $clean,
            head_sha: $head_sha,
            origin_main_sha: $origin_main,
            manifest_version: $manifest_version
        },
        tag: {
            name: $tag,
            sha: ($tag_sha | if length > 0 then . else null end)
        },
        release: {
            exists: $release_exists,
            url: ($release_url | if length > 0 then . else null end)
        },
        package: {
            exact: {
                alias: $expected_version,
                digest: ($exact_digest | if length > 0 then . else null end)
            },
            minor: {
                alias: $minor_alias,
                digest: ($minor_digest | if length > 0 then . else null end)
            },
            major: {
                alias: $major_alias,
                digest: ($major_digest | if length > 0 then . else null end)
            }
        },
        workflow: {
            id: ($workflow_id | if length > 0 then . else null end),
            status: ($workflow_status | if length > 0 then . else null end),
            conclusion: ($workflow_conclusion | if length > 0 then . else null end),
            url: ($workflow_url | if length > 0 then . else null end),
            publish_conclusion: (
                $publish_conclusion
                | if length > 0 then . else null end
            )
        }
    }'
