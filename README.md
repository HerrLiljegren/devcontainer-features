# Dev Container Features

This repository publishes [`workbench`](src/workbench): an opinionated,
terminal-only development environment with coding agents, Git tools, Neovim,
Zsh, and pinned public dotfiles.

Projects choose their own SDK versions and give Workbench one named state
volume. Workbench installs no credentials and requires no editor integration.

## Update and release

Workbench pins its external tools in `src/workbench/versions.env` and
`src/workbench/checksums.env`. Authenticate GitHub CLI once, then preview or
apply an update:

```sh
gh auth login -h github.com
scripts/workbench-update.sh major
scripts/workbench-update.sh major --apply
```

`patch` stays within the current major/minor line, `minor` stays within the
current major line, and `major` allows stable major upgrades. The default is a
preview. Applying an update writes the pins and checksums and increments the
Workbench patch version.

Review, commit, and push the change. After CI succeeds, publish the current
`main` branch:

```sh
gh workflow run release.yaml --ref main
```

The release workflow only publishes the Feature and its `:2`, `:2.0`, and
exact-version aliases. CI owns validation and container builds.
