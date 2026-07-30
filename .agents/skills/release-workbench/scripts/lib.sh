#!/usr/bin/env bash

version_key() {
    local value="${1#v}"
    [[ "$value" =~ ^([0-9]+\.[0-9]+\.[0-9]+)(-[0-9]+)?$ ]] || return 1
    printf '%s\n' "${BASH_REMATCH[1]}"
}

version_gt() {
    [[ "$1" != "$2" && "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n1)" == "$1" ]]
}

eligible_version() {
    local current candidate current_major current_minor candidate_major candidate_minor
    current="$(version_key "$1")" || return 1
    candidate="$(version_key "$2")" || return 1
    current_major="${current%%.*}"
    current_minor="${current#*.}"
    current_minor="${current_minor%%.*}"
    candidate_major="${candidate%%.*}"
    candidate_minor="${candidate#*.}"
    candidate_minor="${candidate_minor%%.*}"
    version_gt "$candidate" "$current" || return 1

    case "$3" in
        patch) [[ "$candidate_major" == "$current_major" && "$candidate_minor" == "$current_minor" ]] ;;
        minor) [[ "$candidate_major" == "$current_major" ]] ;;
        major) return 0 ;;
        *) return 2 ;;
    esac
}

select_best() {
    local current="$1" update_level="$2" candidates="$3" candidate best=""
    while IFS= read -r candidate; do
        [[ -n "$candidate" ]] || continue
        if eligible_version "$current" "$candidate" "$update_level"; then
            if [[ -z "$best" ]] || version_gt "$(version_key "$candidate")" "$(version_key "$best")"; then
                best="$candidate"
            fi
        fi
    done <<< "$candidates"
    [[ -n "$best" ]] && printf '%s\n' "$best"
}

next_feature_version() {
    local current="$1" update_level="$2"
    local feature_major feature_minor feature_patch
    IFS=. read -r feature_major feature_minor feature_patch <<< "$current"
    [[ "$feature_major" =~ ^[0-9]+$ && "$feature_minor" =~ ^[0-9]+$ && "$feature_patch" =~ ^[0-9]+$ ]] || return 2

    case "$update_level" in
        major) printf '%s.%s.0\n' "$feature_major" "$((feature_minor + 1))" ;;
        patch|minor) printf '%s.%s.%s\n' "$feature_major" "$feature_minor" "$((feature_patch + 1))" ;;
        *) return 2 ;;
    esac
}

classify_release_state() {
    local expected_sha="$1" manifest_version="$2" expected_version="$3"
    local tag_sha="$4" release_exists="$5" package_digest="$6"
    local workflow_status="$7" workflow_conclusion="$8" publish_conclusion="$9"

    if [[ "$manifest_version" != "$expected_version" ]]; then
        printf 'conflict\n'
    elif [[ -n "$tag_sha" && "$tag_sha" != "$expected_sha" ]]; then
        printf 'conflict\n'
    elif [[ "$release_exists" == true && "$tag_sha" != "$expected_sha" ]]; then
        printf 'conflict\n'
    elif [[ "$tag_sha" == "$expected_sha" && "$release_exists" == true && -n "$package_digest" ]]; then
        printf 'complete\n'
    elif [[ "$workflow_status" != completed && -n "$workflow_status" ]]; then
        printf 'workflow-in-progress\n'
    elif [[ -n "$package_digest" && "$publish_conclusion" == success && "$release_exists" == false && -z "$tag_sha" ]]; then
        printf 'resume-release\n'
    elif [[ "$workflow_conclusion" == failure ]]; then
        printf 'workflow-failed\n'
    elif [[ -z "$package_digest" && "$release_exists" == false && -z "$tag_sha" ]]; then
        printf 'ready\n'
    else
        printf 'conflict\n'
    fi
}
