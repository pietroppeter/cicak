# cicak 🦎
A Read-Eval-Print-Loop for Nim

> *Cicak-cicak di dinding, diam-diam merayap.*
> *Datang seekor nyamuk, hap! Lalu ditangkap.*
>
> Little geckos on the wall, creeping quietly.
> Along comes a mosquito, hap! And it's caught.
>
> Indonesian children's song

**Cicak** is said *CHEE-chak*: in Malay and Indonesian a "c" sounds like the Italian "ci"
or the English "ch". It is the name of the small house gecko of Southeast Asia, and it
imitates its call, *cak, cak, cak*. Why we picked it is in the
[dev log](https://pietroppeter.github.io/cicak/blog/2026-11-01-cicak.html).

Status: research. Nothing to install yet. The idea: each input becomes a Nim module, a
long-running process loads it with hot code reloading, and incremental compilation
(`nim ic`) keeps each step cheap. The research and the first proof of concept are posts
in the [dev log](https://pietroppeter.github.io/cicak/) (published with GitHub Pages from `main`).

## Playground

[cicak-app](https://github.com/pietroppeter/cicak-app) is a playground for these ideas,
deployed with [Disco](https://disco.cloud) at <https://cicak.pietroppeter.xyz> (its first
deploy is in progress, so the site may not be up yet). Pick a notebook and add its
predefined cells one at a time to a live Nim process, choosing the compiler (`nim c`, or
`nim ic` for incremental compilation) and how cells run (hot code reloading into one
long-running host, or re-running the whole program each time). Each step shows its
output and how long it took.

## Benchmark

[`bench/`](bench) measures how long each cell takes in every mode (`nim c` or `nim ic`,
re-run or hot reload) and build mode, over four scenarios: integer variables, learning
`std/tables`, exploring arraymancer, and exploring the result of a heavy computation.
Results: <https://pietroppeter.github.io/cicak/bench/results.html> (with the
[design](https://pietroppeter.github.io/cicak/bench/design.html) and every cell of the
[scenarios](https://pietroppeter.github.io/cicak/bench/scenarios.html)), published with the
dev log. Design and decisions: [bench/DESIGN.md](bench/DESIGN.md). The benchmark runs on chosen
machines, never on CI; CI only renders these pages from the results committed in `bench/results/`.

## Dev log

- 2026-11-01 [Cicak, the chirping gecko](https://pietroppeter.github.io/cicak/blog/2026-11-01-cicak.html): why the REPL is called cicak ([source](docs/blog/cicak.nim))
- 2026-10-31 [A working PoC with Hot Code Reloading and Incremental Compilation](https://pietroppeter.github.io/cicak/blog/2026-10-31-hcr-poc.html) ([source](docs/blog/hcr_poc.nim))
- 2026-10-31 [How could a Nim REPL work?](https://pietroppeter.github.io/cicak/blog/2026-10-31-research.html) ([source](docs/blog/research.nim))

When you add a post, add it to this list too.

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

The official linux_x64 tarball was rebuilt on 2026-10-28 and now ships `nifler` and
`nifmake` too. [`tools/cloud-setup.sh`](tools/cloud-setup.sh) installs it (falling back
to the source build above if the tools are missing) and links everything into
`/usr/local/bin`. It is the setup script for Claude Code cloud sessions: paste it into
the environment's Setup script field.

Dependencies are managed with [atlas](https://github.com/nim-lang/atlas):

```sh
atlas install
```

Tasks are in `config.nims`, so they run with `nim` (no nimble needed):

```sh
nim docs       # renders the site in one program (docs/all.nim): posts in docs/blog (running the experiments), the index, the benchmark pages
nim specview   # renders the OpenSpec review page to specview.html
```

nimib's markdown dependency uses `std/re`, so `libpcre.so.3` must be installed (on
Debian/Ubuntu: `apt install libpcre3`).

## Experiments

- [experiments/hcr-cells](experiments/hcr-cells): cells as modules, added to a running
  process with hot code reloading. `run.nim` starts a host with one cell, then adds two
  more without restarting it.
- [experiments/ic-chain](experiments/ic-chain): times `nim ic` on a chain of 20 cell
  modules and on adding a 21st.
- [experiments/hcr-ic](experiments/hcr-ic): hot code reloading with `nim ic`, which
  does not link on Nim 2.4; the README explains why.

## License

MIT
