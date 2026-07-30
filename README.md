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
preview. Applying a `patch` or `minor` update increments the Workbench patch
version. Applying a `major` dependency update increments the Workbench minor
version and resets its patch version. Workbench major versions are reserved for
intentional breaking or structural changes to the Feature itself.

Review, commit, and push the change. After CI succeeds, publish the current
`main` branch:

```sh
gh workflow run release.yaml --ref main
```

The release workflow only publishes the Feature and its metadata-derived
major, minor, and exact-version aliases. CI owns validation and container
builds.
