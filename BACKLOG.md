# Backlog

Ideas and possible next steps for the REPL. The research behind them is in the
[research post](docs/blog/research.nim).

Lifecycle of an idea:
1. It starts here.
2. When it is picked up, it becomes an OpenSpec change (`/opsx:propose`, under
   `openspec/changes/`). The entry stays here, marked *in progress* with the change name.
3. When the change is implemented and archived (`/opsx:archive`), the entry is removed
   from this file and a line is added to [CHANGELOG.md](CHANGELOG.md).

Each entry says what the idea is and why it matters. Rough size: S (hours), M (a day or
two), L (more).

## Engine

- **Engine library with a re-run backend** (M). A session object with `eval`,
  `complete`, `inspect`, `interrupt` and `reset`, where each input is appended to a
  buffer that is recompiled and re-run (INim's approach). Works everywhere and gives the
  API something real to stand on before the HCR backend.
- **HCR backend** (L). Turn `experiments/hcr-cells` into a backend: generate a module
  per input, add `*` to its top-level declarations, regenerate `cells.nim`, and use
  `import cell_K except x` when a later input redefines a name. Fall back to restart and
  re-run when HCR can't reload (changed types).
- **Showing values** (S). `>>> x` prints the value and its type: compile the bare
  expression and, when the compiler says it has to be discarded, wrap it in `echo`.
- **Automatic exports** (S). Each input is a module that imports the earlier ones, and
  Nim imports are not transitive, so today a cell has to write `export arraymancer` after
  `import arraymancer` and `x*` for its variables, or later cells can't see them (the
  benchmark scenarios do this by hand). The engine should add both: an `export` for every
  module a cell imports, and `*` on its top-level declarations, so a user writes plain Nim.
  No cost in compile time: the compiler does the same work either way.
- **HCR together with IC** (L, upstream). Tried 2026-11-01: `nim ic --hotCodeReloading:on`
  fails to link on Nim 2.4; the IC backend does not support HCR (three layers, a
  partial compiler patch and a repro in `experiments/hcr-ic/`). Next step, if it
  matters: a nim-lang issue. Meanwhile HCR uses `nim c`, and re-run uses `nim ic`.
- **Other C compilers** (S). The PoC used gcc only. Try zig cc, which nimlang ships.

## Service and front ends

- **stdio JSON-RPC server** (M). Expose the engine as JSON-RPC 2.0 over stdio, with
  output streamed as notifications (protocol sketch in the research post). An optional
  Unix or TCP socket later lets several front ends share a session.
- **Terminal front end** (S). A thin client over the server.
- **Jupyter kernel** (M). Translate Jupyter messages into server calls.
- **Python client** (M). For notebooks and nimlang.

## Reactive notebook

- **Dependency analysis** (M). Find which globals each cell defines and reads; check
  whether parsing is enough or the compiler's semantic check (or IC's symbol data) is
  needed.
- **Marimo-style notebook** (L). Cells form a dependency graph of modules, each cell's
  body is a `runCell` proc, edits recompile and re-run only the affected cells, widget
  changes re-run without compiling.

## Questions

- **nlvm's REPL** (S). Ask arnetheduck whether `nlvm r` keeps state across lines.
