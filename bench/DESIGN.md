# cicak benchmark: design

The benchmark measures how long a Nim REPL built on cicak's mechanism makes you wait,
cell by cell. It drives the same mechanism as the playground
([cicak-app](https://github.com/pietroppeter/cicak-app)): each cell is a module that
imports the earlier cells, compiled with `nim c` or `nim ic`, and run by re-running
the whole program or by hot code reloading into a running host.

This file records what is measured and why. The results are on the results page,
rendered by `bench/results.nim`, which also says what was run (scenarios, modes, runs);
`bench/design.nim` renders this file as a page next to it. The design was reviewed and agreed on 1 November 2026.

## What is compared

Four modes, and three build modes for each.

| Mode | Each cell | Runs which code |
| --- | --- | --- |
| `c+rerun` | `nim c` the program importing every cell, run it | every cell again |
| `ic+rerun` | the same with `nim ic` (incremental compilation) | every cell again |
| `c+hcr` | `nim c --hotcodereloading:on` the host, `performCodeReload()` | the new cell only |
| `ic+hcr` | the same with `nim ic` | the new cell only |

- `ic+hcr` fails on Nim 2.4 (the link step in nifc, see BACKLOG "HCR together with IC").
  It stays in the matrix, so the results show it failing and pick it up once it works.
- Build modes: debug (no flag), `-d:release`, `-d:danger`. Debug and release run for
  every scenario; danger runs for scenario 3 only, where compute time matters.
- Re-run and hot reload do different work on purpose: re-run time grows with the
  number of cells, hot reload time should stay flat. That is a result to show, not
  noise to remove.

Not compared yet: other C compilers (`clang`, `tcc`, `zig cc`). `CICAK_CC` selects the
compiler the wrapper calls, so this is a matter of running it.

## Scenarios

Each scenario answers one question. Every cell is shown on the scenarios page
(`bench/scenarios_page.nim`). Scenarios 1 to 3 are notebooks in
`bench/scenarios/`, in the same percent format as the playground's notebooks
(`# %% title` starts a cell), so the playground can show them too.

| Id | Scenario | Question | Cells |
| --- | --- | --- | --- |
| s0 | Integer variables (generated) | fixed cost of a cell, and how it grows with the number of cells | 100 |
| s1 | Learning `std/tables` | what a realistic light session costs | 20 |
| s2 | Exploring arraymancer | what a large dependency costs on import and per cell afterwards | 20 |
| s3 | Compute something heavy, then explore it | how much re-run pays for recomputing state that hot reload keeps | 20 |

Decisions:

- **"Changing" a variable means assigning, not redefining.** Cells are modules that
  import every earlier cell, so a second `var x` makes every later use of `x` ambiguous.
  s0 adds a variable in two of every three cells and assigns to an earlier one in the
  third. Redefinition gets its own scenario once cicak handles it (`import cell_K except x`).
- **s0's variables depend on each other**: each new variable is the latest minus the one before
  it (`var x5* = x4 - x2`), and each update sets the one before from the latest
  (`x4 = x5 - x4`), so every cell reads symbols from earlier cells, as in a real session. The
  values cycle between -2 and 2, so s0 can run to any length without overflowing.
  The first version (until 1 November 2026) used independent variables; its runs were redone,
  and the calibration session keeps those independent cells so references stay comparable.
- **s0 runs to 100 cells**, since it is cheap and 20 cells barely show the growth.
  It is generated, so any length works (`--s0cells`).
- **s1 uses `std/tables`**: generic, so later cells pay for new instantiations. About
  half of the cells only inspect, as in a real session.
- **Imports happen in cell 1 only** (with `export`), so the import cost is one visible
  spike and later cells show the cost of a cell. Cells that need another module
  (`std/hashes`, `std/strutils`) import it where it is first used.
- **Arraymancer is pinned** (`bench/deps.sh`, commit dcc220c) with its dependencies.
  It is cloned into `bench/deps`, not installed with atlas, because cells compile outside
  the repo and get these directories as `--path:` flags (the `# paths:` line of the
  scenario). With `nim c` it works in every build mode. With `nim ic` on Nim 2.4 the
  compiler crashes (segfault in `nim m` on `tensor/operators_logical.nim`); that is
  recorded as a failed cell, not dropped.
- **s3's computation is deterministic and calibrated**: 100,000 particles for 2,000 steps
  with a fixed seed, about 0.5 s in release on the cloud machine. The cells that explore it
  are cheap, apart from one that derives a second object.
- **Outputs are deterministic** (no clocks, fixed seeds), so the results page can check them.

Possible later scenarios: a cell that fails to compile and then a fixed one (the cost of a
mistake), changing a type that earlier cells use (hot reload has to restart), and editing
an earlier cell (the playground is append-only today).

## What is measured

Each cell's time is split into phases, which the charts stack.

| Phase | How |
| --- | --- |
| Nim | compile wall time minus the C phases |
| C compile | `bench/ccwrap.sh` replaces the C compiler (`--gcc.exe`, `--gcc.linkerexe`) and logs start and end of each call; the phase is the union of the `-c` calls' intervals, since they run in parallel |
| link | the same log, the calls without `-c` |
| run or reload | running `./prog` (re-run), or starting the host and `performCodeReload()` (hot reload) |

The wrapper works for `nim ic` too: nifc calls the same configured compiler.

Also recorded per cell: how many C files were compiled (how much each mode caches), success,
the output, and the log of a failed step.

- **Cell 0 is the session start**: compiling and running the program with no cells (re-run),
  or compiling and starting the host (hot reload). It holds the one-off cost of compiling
  `system`, so cell 1 shows the cost of a cell. Every session total includes cell 0.
- **Hot reload's runtime libraries** (`libnimrtl`, `libnimhcr`) are built once per build mode
  before the sessions; their time is in the run's metadata, not in any session.
- **Cold caches, by design**: every session gets a fresh directory and nimcache, which is
  what a REPL user gets today. Splitting out cell 0 shows what a warm cache could save. A
  variant with a nimcache kept between sessions is a possible follow-up.
- **Warm machine**: a throwaway session runs first, so the OS file cache and the C compiler
  are warm before anything is recorded.
- **Repetitions**: 5 per scenario, mode and build mode, interleaved (repetition, then
  scenario, then build mode, then mode), so a slow minute on the machine doesn't fall on one
  mode. The page shows medians, and min and max as bands and ranges.
- **Failures**: a failed cell ends its session (unless `--keepGoing`), and is reported with
  its error. Timeouts are generous (900 s compile, 600 s run) and count as failures.
- **Snappiness**: the mean time per cell over cells 11 to 20 (the last 10 cells of a 20-cell
  scenario), per scenario, build mode and environment. Under 1 s a REPL feels snappy. It is fixed
  cells rather than a session's own last 10, so s0 compares across runs of different lengths.
  It is shown in raw seconds even across environments, as the one exception to the rule below:
  it is what someone using that machine waits.
- **Output check**: for each scenario and build mode, `c` and `ic` must print the same, and the
  hot reload outputs of cells 1 to k must add up to what re-run prints at cell k.

## Where it runs

Never on CI: `bench/` is excluded from the CI workflow's paths. It runs on chosen machines,
and every result records the machine (CPU, cores, memory, OS), Nim and C compiler versions,
the cicak commit and the arguments.

| Machine | For |
| --- | --- |
| Cloud session (Nim 2.4 at `/opt/nim-2.4.0`, `NIM_LIB` set) | developing the harness, first numbers |
| GitHub Actions runner, run by hand | repeatable reference numbers (not part of CI) |
| Hetzner VPS, the Disco server (2 vCPU, 4 GB) | "what playground visitors get", with `bench/docker/run.sh` at a quiet hour, lighter (3 repetitions, s0 to 40 cells); it shares the machine with the live site |
| Mac (arm64) | not for now: hot reload doesn't work on arm64 (nim-lang/Nim#26581) |

Do nothing else heavy on the machine while it runs: the harness measures wall time.

`bench/docker/` holds an image (Ubuntu 24.04, gcc 13, Nim 2.4.0 from the official tarball,
musl for its nifler and nifmake, libblas for arraymancer) and `run.sh`, which runs the benchmark
in it from a clone of the repository, so any Linux x64 box with Docker can run it. The results
land in the clone's `bench/results/`.

## Environments and normalisation

An environment is a machine the benchmark runs on, named by the run's `--label`. Raw times from
different environments are not comparable: a 2 vCPU VPS is slower than a 4-core cloud machine, and
not uniformly so. These decisions keep comparisons honest:

- **Every run calibrates itself.** It starts and ends with a calibration session, always the same:
  `c+rerun`, debug, 10 cells adding and assigning independent integer variables, then a cell with a fixed CPU-bound loop (it runs
  once, as the last cell). `--calibrationOnly` runs just that, twice, to calibrate an environment
  whose runs predate calibration (as the first cloud runs do).
- **The reference is per phase.** Machines differ unevenly: C compiles run in parallel, so core
  count matters more for C compile than for the Nim frontend, and the run phase depends on CPU
  speed alone. The environment's reference is the median over its calibration sessions of: Nim
  time over cells 1 to 10, C compile and link time over cells 0 to 10, and the run time of the
  fixed computation.
- **Drift**: the calibration at the end of a run against the one at its start shows whether the
  machine slowed down during the run (noisy neighbours, thermal throttling).
- **Raw within, normalised across.** Each environment keeps its own charts in seconds. Charts that
  put environments side by side divide each phase by that environment's reference for the phase,
  and show the result in seconds of the first calibrated environment's reference, so that
  environment's bars equal its raw medians. Raw seconds from two environments never share a chart.
- **Ratios need no reference.** Whole-session time against `c+rerun` in the same build mode and
  environment ("hot reload takes 0.33× the time of re-run on s3") compares environments directly,
  and is the most robust comparison.
- **Aggregating across environments** is done only on normalised values or ratios, with the
  geometric mean (the right average for ratios). Not shown yet: it needs more than one environment.

## Data

Each run writes `bench/results/<date>T<time>-<label>/`:

- `meta.json`: machine, versions, commit, arguments, the label (environment), scenario and cell titles, runtime library build times.
- `steps.jsonl`: one line per step (compile, run, start host, reload) with `scenario`, `mode`,
  `compiler`, `strategy`, `opt`, `rep`, `cell`, `step`, `wallMs`, `nimMs`, `ccMs`, `linkMs`,
  `runMs`, `cFiles`, `ok`.
- `cells.jsonl`: one line per cell with its output, error and the log of a failed step.

Calibration sessions are rows with scenario `cal` (repetition 1 at the start, 2 at the end).

Results are committed, so the page can be rendered anywhere without running the benchmark.

## Results page

`nim r bench/results.nim [run dirs]` renders `bench/results.html` from every run in
`bench/results` (or the ones given), with nimib, the dev log's theme and nim-plotly
(plotly.js from cdn.plot.ly). It starts with how the benchmark is set up (scenarios, modes,
build modes, runs, environments and their references), then the findings. Each environment
gets its own raw sections; a last section compares environments (ratios, and normalised times
once two environments are calibrated). Scenarios are never mixed in a chart or table: the
whole-session totals are one panel per scenario, and each scenario has its own section with a
summary table, its cells, the total wait so far after each cell (one line per mode and build
mode, with the min-max band), and the time per cell stacked by phase, one panel per mode.

## How to run

```sh
atlas install                      # nimib and nim-plotly, for the results page
bench/deps.sh                      # arraymancer and its dependencies, for s2
export NIM_LIB=/opt/nim-2.4.0/lib  # where the cloud environment's Nim keeps its lib
nim c -d:release -o:/tmp/benchbin bench/bench.nim
/tmp/benchbin --scenarios:s0,s1,s2 --opts:debug,release --reps:5 --label:cloud
/tmp/benchbin --scenarios:s3 --opts:debug,release,danger --reps:5 --label:cloud
nim r bench/results.nim
nim r bench/design.nim             # this file as bench/design.html
nim r bench/scenarios_page.nim     # every cell, as bench/scenarios.html
```

On another machine with Docker: `bench/docker/run.sh <label> [options]` (see the script).

A full run takes a few hours on 4 cores. `--reps:1 --s0cells:10` gives a quick check.
