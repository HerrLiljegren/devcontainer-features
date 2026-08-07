# Workbench

An opinionated, terminal-only development environment for Debian- and
Ubuntu-based Dev Containers on amd64 and arm64.

It installs:

- Codex, Claude Code, OpenCode, and Hunk
- Curated Matt Pocock skills for Codex: implementation, planning, triage,
  reviews, research, design, debugging, and handoffs
- Worktrunk, Git, GitHub CLI, Lazygit, and delta
- Neovim 0.12.4 with pinned [HerrLiljegren/dotfiles](https://github.com/HerrLiljegren/dotfiles)
- Zsh, Starship, fzf, zoxide, eza, and bat
- Python 3, ripgrep, fd, jq, yq, and ShellCheck
- Azure DevOps MCP and Azure Artifacts Credential Provider

It installs no credentials and has no dependency on VS Code.

## Updating the Workbench

From the Feature repository:

```text
$release-workbench patch
$release-workbench minor
$release-workbench major
```

The repository-local skill refreshes pins and checksums, validates the Feature,
creates the approved release commit, waits for CI, and publishes the exact
commit through GitHub Actions.

## Use it

Each repository needs a stable volume name. Use that same name in all of the
repository's worktrees, and a different name for unrelated repositories.

```json
{
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
  "features": {
    "ghcr.io/herrliljegren/devcontainer-features/workbench:2": {}
  },
  "mounts": [
    "source=my-repository-workbench-state,target=/workbench-state,type=volume"
  ]
}
```

Projects add their own SDK Features, such as .NET. Workbench deliberately does
not choose project runtime versions.

Start and enter the container without an editor:

```sh
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . zsh -l
```

For a linked Git worktree, add `--mount-git-worktree-common-dir` to
`devcontainer up`. Worktrunk stores worktrees under the repository's
`.worktrees` directory, and Workbench enables Git's relative worktree paths.

## What survives a rebuild

The named volume stores only selected user state:

- Codex authentication, sessions, and history
- Claude authentication and sessions
- OpenCode authentication and sessions
- GitHub CLI authentication
- Azure DevOps MCP credentials
- Azure Artifacts session tokens
- Zsh history

Binaries, SDKs, editor plugins, package caches, and the rest of the home
directory are recreated. Delete the named volume to reset all Workbench
authentication for that repository.

## Curated Codex skills

Workbench pins these image-owned skills from
[mattpocock/skills](https://github.com/mattpocock/skills): `implement`,
`to-spec`, `to-tickets`, `tdd`, `diagnosing-bugs`, `code-review`,
`codebase-design`, `domain-modeling`, `research`, `prototype`,
`resolving-merge-conflicts`, `wizard`, `grilling`, `writing-for-agents`,
`grill-with-docs`, `improve-codebase-architecture`, `wayfinder`, `triage`,
`grill-me`, and `handoff`.

They are available through Codex's normal skills discovery. The Feature owns
their pinned source; Codex state holds only links. A user-owned skill with the
same name is not overwritten during bootstrap.

## Authenticate

Use the tools' normal login commands after the container starts:

```sh
codex login
claude
opencode
gh auth login -h github.com
```

For private Azure Artifacts feeds:

```sh
dotnet restore --interactive
```

For Azure DevOps MCP, create `/workbench-state/azure-devops-mcp/env` with mode
`600`:

```sh
AZURE_DEVOPS_ORG=tengella
PERSONAL_ACCESS_TOKEN=<base64 user:PAT value>
export AZURE_DEVOPS_ORG PERSONAL_ACCESS_TOKEN
```

Agent configuration can launch `/usr/local/bin/workbench-azure-devops-mcp`.
The wrapper reads the runtime file without putting its contents in the image,
dotfiles, or project repository.
