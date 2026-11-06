# ci Specification

## Purpose
Continuous integration and publishing for the repository (`.github/workflows/ci.yml`).

## Requirements

### Requirement: Nim 2.4 from the release tarball, cached
CI SHALL install Nim from the official linux_x64 tarball of `NIM_VERSION` (2.4.0), which
ships `nifler`, `nifmake` and atlas, verified by its sha256, and SHALL cache it by that
sha256, so it is downloaded again only when the tarball changes. Nim is not built from
source on CI.

#### Scenario: Tarball unchanged
- **WHEN** a push runs CI and the tarball's sha256 matches the cached one
- **THEN** Nim comes from the cache and nothing is downloaded but the sha256

### Requirement: Bounded and non-redundant runs
CI jobs SHALL have time limits, so a hanging experiment cannot hold a runner for hours, and
a new push to a pull request SHALL cancel that pull request's run still in progress.

#### Scenario: Two quick pushes to a PR
- **WHEN** a second commit is pushed while the first one's CI is running
- **THEN** the first run is cancelled and only the second one completes

### Requirement: Skip CI for non-code changes
CI SHALL NOT run for pushes or pull requests that only change Markdown files, `LICENSE`,
`.gitignore`, `openspec/` or `.claude/`.

#### Scenario: OpenSpec-only change
- **WHEN** a pull request only changes files under `openspec/changes/`
- **THEN** no CI run starts

#### Scenario: Dev log change
- **WHEN** a change touches `docs/`
- **THEN** CI runs, so the dev log is rebuilt

### Requirement: Dev log
CI SHALL install dependencies with atlas and render the dev-log posts in `docs/blog`,
then the index page `docs/index.nim`, then the benchmark pages from the committed
results, all in one program (`docs/all.nim`, run by `nim docs`), so the site is compiled
once. On `main`, after this succeeds, it SHALL deploy the posts, the index and the
benchmark pages to GitHub Pages, with the index as the site root.

#### Scenario: Merge to main
- **WHEN** a commit lands on `main` and the docs job passes
- **THEN** the dev log is deployed to GitHub Pages, and the site root lists the posts

### Requirement: OpenSpec review page
For pull requests that touch `openspec/` or `BACKLOG.md`, CI SHALL render
`tools/specview.nim`'s review page, post its summary on the run page and attach the page
as the `specview` artifact.

#### Scenario: Proposal PR
- **WHEN** a pull request adds a change under `openspec/changes/`
- **THEN** the OpenSpec review workflow runs and attaches `specview`
