# Dev Container Features

This repository publishes [`workbench`](src/workbench): an opinionated,
terminal-only development environment with coding agents, Git tools, Neovim,
Zsh, and pinned public dotfiles.

Projects choose their own SDK versions and give Workbench one named state
volume. Workbench installs no credentials and requires no editor integration.

## Update and release

Workbench pins its external tools in `src/workbench/versions.env` and
`src/workbench/checksums.env`. Use the release helper to preview staged updates;
it resolves dotfiles, npm packages, GitHub release assets, and their checksums:

```sh
scripts/workbench-release.sh update --level patch
scripts/workbench-release.sh update --level minor --apply
scripts/workbench-release.sh release --level patch --base 2.0 \
  --apply --commit --tag --push --publish
```

`patch` stays within the current major/minor line, `minor` stays within the
current major line, and `major` allows stable major upgrades. The default is a
dry run. Applying changes only edits the repository unless the explicit
`--commit`, `--tag`, `--push`, and `--publish` flags are supplied. Every current
Workbench source is queried; a failed upstream metadata lookup stops the
update rather than silently changing only part of the toolbox.

The updater reads public GitHub release metadata through an authenticated GitHub
CLI session or `GITHUB_TOKEN`. Authenticate once on the machine that runs it:

```sh
gh auth login -h github.com
```
