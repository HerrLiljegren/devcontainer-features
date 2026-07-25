# Workbench

An opinionated, terminal-only development environment for Debian- and
Ubuntu-based Dev Containers on amd64 and arm64.

It installs:

- Codex 0.144.3, Claude Code 2.1.197, OpenCode 1.18.5, and Hunk 0.17.0
- Worktrunk 0.67.0, Git 2.55.0, GitHub CLI 2.96.0, Lazygit 0.63.0, and delta 0.19.2
- Neovim 0.12.4 with pinned [HerrLiljegren/dotfiles](https://github.com/HerrLiljegren/dotfiles)
- Zsh, Starship 1.26.0, fzf 0.74.0, zoxide 0.10.0, eza 0.23.5, bat 0.26.1
- Python 3, ripgrep 15.1.0, fd 10.4.2, jq, yq 4.53.3, and ShellCheck
- Azure DevOps MCP 2.8.1 and Azure Artifacts Credential Provider 2.0.2

It installs no credentials and has no dependency on VS Code.

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

## Authenticate

Use the tools' normal login commands after the container starts:

```sh
codex login
claude
opencode
gh auth login
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
