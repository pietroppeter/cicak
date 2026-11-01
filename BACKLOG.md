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
- **HCR together with IC** (S). Try `nim ic --hotCodeReloading:on`; the PoC measured
  them separately (about 1 s per cell with `nim c`, 0.4 s with `nim ic`).
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
