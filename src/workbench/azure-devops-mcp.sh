#!/bin/sh
set -eu

env_file="${WORKBENCH_STATE_DIR:-/workbench-state}/azure-devops-mcp/env"

if [ ! -r "$env_file" ]; then
    echo "Azure DevOps MCP credentials are missing: $env_file" >&2
    exit 1
fi

# shellcheck disable=SC1090
. "$env_file"

: "${AZURE_DEVOPS_ORG:?Set AZURE_DEVOPS_ORG in $env_file}"
: "${PERSONAL_ACCESS_TOKEN:?Set PERSONAL_ACCESS_TOKEN in $env_file}"

exec mcp-server-azuredevops "$AZURE_DEVOPS_ORG" --authentication pat "$@"
