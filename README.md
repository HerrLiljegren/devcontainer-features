# Dev Container Features

This repository publishes [`workbench`](src/workbench): an opinionated,
terminal-only development environment with coding agents, Git tools, Neovim,
Zsh, and pinned public dotfiles.

Projects choose their own SDK versions and give Workbench one named state
volume. Workbench installs no credentials and requires no editor integration.

## Update and release

Workbench pins its external tools in `src/workbench/versions.env` and
`src/workbench/checksums.env`. Releases are prepared and published with the
repository-local, user-invoked skill:

```text
$release-workbench patch
$release-workbench minor
$release-workbench major
```

`patch` stays within the current major/minor line, `minor` stays within the
current major line, and `major` allows stable major upgrades. Patch and minor
dependency releases increment the Workbench patch version. Major dependency
releases increment the Workbench minor version and reset its patch version.
Workbench major versions are reserved for intentional breaking or structural
changes to the Feature itself.

The skill previews and validates every update, asks once for approval, creates
the atomic release commit, waits for push CI, and dispatches the release
workflow for that exact version and commit. GitHub Actions publishes the
Feature's major, minor, and exact-version aliases before creating a `vX.Y.Z`
GitHub Release with generated notes. Exact releases are immutable.
