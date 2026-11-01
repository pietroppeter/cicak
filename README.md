# nim-repl
A Read-Eval-Print-Loop for Nim

Status: research. Nothing to install yet. The idea: each input becomes a Nim module, a
long-running process loads it with hot code reloading, and incremental compilation
(`nim ic`) keeps each step cheap. The research and the first proof of concept are posts
in the [dev log](docs/blog) (published with GitHub Pages from `main`).

## How we work

- **Ideas** go in [BACKLOG.md](BACKLOG.md). When an idea has been implemented, it moves
  from the backlog to [CHANGELOG.md](CHANGELOG.md).
- **Changes** are planned with [OpenSpec](https://github.com/Fission-AI/OpenSpec).
  `openspec/specs/` describes how the project behaves today, and each change gets a
  proposal, spec deltas, a design and tasks under `openspec/changes/`. With Claude Code,
  use `/opsx:propose`, `/opsx:apply` and `/opsx:archive`. With another tool, use the
  `openspec` CLI (`npm i -g @fission-ai/openspec`).
- **Reviewing changes**: `nim specview` writes `specview.html`, a page showing where each
  change is in the process, its proposal and tasks, its spec deltas and the changed
  files. On PRs that touch `openspec/` or `BACKLOG.md`, CI posts a summary on the run
  page and attaches the full page as the `specview` artifact.
- **Dev log**: dated [nimib](https://github.com/pietroppeter/nimib) posts in `docs/blog`,
  listed by `docs/index.nim`, with the theme in `docs/theme.nim`. Posts that report on
  an experiment run it when they are rendered, so they show real output.
- Changes that only touch Markdown, `openspec/` or `.claude/` don't trigger the main CI.

## Setup

This project targets Nim 2.4. `nim ic` needs the `nifler` and `nifmake` tools, which the
2.4.0 release binaries are missing ([forum thread](https://forum.nim-lang.org/t/14255)).
Building Nim from source includes them:

```sh
git clone -b version-2-4 https://github.com/nim-lang/Nim
cd Nim
sh build_all.sh     # builds bin/nim, bin/nifler, bin/nifmake
./koch atlas        # builds bin/atlas
```

Dependencies are managed with [atlas](https://github.com/nim-lang/atlas):

```sh
atlas install
```

Tasks are in `config.nims`, so they run with `nim` (no nimble needed):

```sh
nim docs       # renders the dev log: posts in docs/blog (running the experiments), then the index
nim specview   # renders the OpenSpec review page to specview.html
```

nimib's markdown dependency uses `std/re`, so `libpcre.so.3` must be installed (on
Debian/Ubuntu: `apt install libpcre3`).

## Experiments

- [experiments/hcr-cells](experiments/hcr-cells): cells as modules, added to a running
  process with hot code reloading. `run.sh` starts a host with one cell, then adds two
  more without restarting it.
- [experiments/ic-chain](experiments/ic-chain): times `nim ic` on a chain of 20 cell
  modules and on adding a 21st.

## License

MIT
