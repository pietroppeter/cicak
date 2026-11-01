import nimib
import std/os
import ../theme
import ../diagram

nbInit
nb.title = "How could a Nim REPL work?"
# dated slug for the dev log
nb.doc.filename = nb.doc.filename.parentDir / "2026-10-31-research.html"
nb.useTheme(
  titleHtml = "How could a Nim <em>REPL</em> work?",
  eyebrow = "dev log · 31 October 2026",
  epigraph = "Prior art, a design where each input is a module, a service any front end can use, and a marimo-style notebook.",
  meta = "research · rendered with nimib",
  summary = "Research: prior art for Nim REPLs, the cells-as-modules design, a library and service architecture, and a reactive notebook.",
)

nbText: """
## Summary

A usable Nim REPL is within reach by treating each input as a Nim module, loaded into a long-running process
with hot code reloading (HCR), with incremental compilation (IC, Nim 2.4) keeping each compile cheap.
This is the direction Araq suggested, and both pieces work on Nim 2.4.0 in a quick test (see What I measured below).

- Today's tools (INim, jupyternim) re-run the whole session on every input: about 0.75 s per input even with a warm cache, and side effects run again each time.
- `nim secret` answers instantly but runs in the compiler VM, which cannot call C code.
- It should be a standalone project: an engine library, a server binary any front end can drive (terminal, Jupyter, editors, Python), and thin clients.
- The same engine can power a marimo / Pluto.jl style reactive notebook, where cells form a dependency graph of modules.
- Recommended first step: the library with the simple re-run backend, a stdio JSON-RPC server and a terminal client, then the HCR backend.

## Where the idea came from

A REPL for Nim is an idea probably as old as Nim itself. It resurfaced recently in Pietro's forum thread
[uv add nimlang and other scientific Nim experiments](https://forum.nim-lang.org/t/14230) (2026-10-18),
where two replies point to two different designs.

- **Araq**: "Other project idea: Ask Claude to give Nim a REPL now that IC and hot-code-reloading begin to work."
  This points to compiled cells reloaded into a live process.
- **arnetheduck (Jacek)**: "fwiw, `nlvm` has a repl already for nim and can cross-compile similar to zig
  (although zig supports more platforms at the moment) - it might be interesting in this context:
  https://github.com/arnetheduck/nlvm#repl--running-your-code". This points to a JIT, using LLVM's ORCv2.

## Prior art

Every existing Nim REPL either re-runs everything, runs in the VM, or depends on a second compiler.
The two building blocks for doing better, HCR and IC, are in the compiler, but neither is a REPL by itself.

| Approach | Example | How state is kept | Strengths | Weaknesses |
| --- | --- | --- | --- | --- |
| Re-run | [INim](https://github.com/inim-repl/INim), [jupyternim](https://github.com/stisa/jupyternim) | Not kept: each input is appended to a buffer file, which is recompiled and re-run with `nim c -r`, old output hidden | Full Nim, FFI works, simple | Cost grows with the session; I/O, randomness and long computations run again every time |
| VM | `nim secret`, [NimScript](https://nim-lang.org/docs/nims.html) | In the compiler VM | Instant, real persistent state | No FFI, so many stdlib modules fail; `ptr`, `ref ref` and multimethods are shaky; slow for numeric work |
| JIT | [nlvm](https://github.com/arnetheduck/nlvm) `nlvm r` | LLVM ORCv2 JIT in the process | Real REPL at native speed | Pins its own Nim version; ignores `header`, `emit`, `importcpp`; parts of stdlib unavailable; heavy LLVM build |
| Hot code reloading | [`--hotCodeReloading:on`](https://nim-lang.org/docs/hcr.html) | Each module is a `.so`; globals survive reloads | Native code, keeps state, per-module | Main module not reloadable; type changes can't reload; old libraries leak memory under orc; tested only with `--threads:off`; no arm64 glibc |
| Incremental compilation | `nim ic` (Nim 2.4) | A cache, not a REPL | One-line edit rebuild 0.45 s vs 22 s on Araq's benchmark | Cold builds can be slower (Atlas: 11.6 s vs 4.1 s, Sept 2026); the 2.4.0 release shipped without the `nifler` tool `ic:on` needs |

jupyternim's own TODO list says it: "find a better way to fake a repl than re running prior code and discarding output
(we have HCR! Buggy though)". IC numbers are from Araq's [progress thread](https://forum.nim-lang.org/t/13585);
the 2.4.0 packaging bug is in [thread 14255](https://forum.nim-lang.org/t/14255).

## What I measured

**Nim 2.2.6** (the version the `nimlang` package installs from PyPI), gcc, Linux:

- **`nim secret`** handles pure code: `std/math`, `std/tables`, procs and ref objects all work.
  `now()` from `std/times` fails with "VM not allowed to do FFI", any `importc` fails the same way,
  and `std/os` procs like `getCurrentDir` are missing.
- **Re-run cost**: recompiling and running a small edited file with `nim c -r` takes about 0.75 s with a warm cache
  and 20 s cold. That is the minimum wait per input for INim's approach.
- **HCR**: the [cells test](2026-10-31-hcr-poc.html)
  crashes at startup (the main module never initialises its HCR function pointers), with orc or refc, threads on or off.

**Nim 2.4.0** built from source (the `version-2-4` branch still equals the `v2.4.0` tag on 2026-10-31), gcc, Linux:

- **IC works** when the compiler is built from source, because `koch boot` builds `nifler` and `nifmake` into `bin/`.
  The missing `nifler` is only a problem of the released binaries.
- **IC per-cell cost**: in a [chain of 20 cell modules](https://github.com/pietroppeter/nim-repl/tree/main/experiments/ic-chain),
  each importing and re-exporting the previous one, the first `nim ic` took 5.8 s and adding a 21st cell took **0.43 s**.
  A no-op `nim ic` takes 0.03 s; a one-line edit of a small program 0.54 s, against 0.9 to 1.2 s for `nim c`.
- **HCR works**: the same cells test runs on 2.4.0. Adding `c2.nim` and then `c3.nim` to a running process
  (recompile about 1.05 s each, then `performCodeReload()`) ran only the new cells' top-level code,
  and kept the values of earlier globals (`y` stayed 42 after `c3` set `x = 100`).
"""

nbText: """
## REPL design: each input is a module

This design follows Araq's suggestion. Each input becomes a module, a long-running process holds the state,
and earlier inputs never run again.

1. **Each input (cell) becomes a module** `cell_N.nim`. It imports and re-exports the earlier cells.
   Its top-level declarations are rewritten to be exported (`x` becomes `x*`), using the compiler's parser so the rewrite is syntax-aware.
2. **A long-running host process** is built with HCR. Its reloadable module imports all the cells.
   Adding a cell means recompiling and calling `performCodeReload()`. HCR loads the new `.so`,
   runs its initialisation and keeps the earlier globals.
3. **IC keeps each step cheap.** The stdlib and earlier cells are already cached,
   so only the new module needs checking and its C code compiling.
4. **Redefinitions** such as `let x = 1` followed later by `let x = "a"` would be ambiguous across modules.
   The REPL keeps a symbol table and generates `import cell_K except x` for names that a later cell redefines.
5. **Fallback**: when HCR can't apply a change (a changed type, or an edit to an earlier Jupyter cell),
   the REPL restarts the host and re-runs everything, as INim does.
6. **Showing values**: `>>> x` should print the value and its type. This can reuse INim's trick:
   compile the bare expression, and when the compiler says it has to be discarded, wrap it in `echo`.

## Library and service architecture

The REPL should be its own project, not part of nimlang: an engine library, a server binary that any tool can drive,
and thin front ends. Rust's evcxr is the closest example for a compiled language. It is one library crate with a separate
terminal REPL and Jupyter kernel, and each cell is compiled to a dylib and loaded into a child process that holds the state.
Clojure's nREPL (one server, many editors), xeus (a C++ library for writing Jupyter kernels),
LSP (JSON-RPC over stdio) and Nim's own nimsuggest show how to run the shared part as a service.
"""

nbRawHtml: architectureSvg()

nbText: """
The user's code runs in a separate worker, so a crash or hang never takes down the server.
Stdio is the default because a front end just launches the server, with no ports or auth to manage.
A TCP socket would need a token.

Protocol sketch (JSON-RPC requests with an `id`, output streamed as notifications):

- `initialize`: returns capabilities, the Nim version and the backend in use
- `session/new`, `session/close`, `session/reset`
- `eval {session, code}`: streams `output {stream, text}` notifications, then returns `{value, type}` or `{diagnostics}`
- `complete` and `inspect`, which could reuse `nim track` or nimsuggest
- `interrupt {session}`

Build order: the library with the re-run backend, the stdio server and a terminal client first.
Then the Jupyter adapter, then the HCR backend.

## A reactive notebook, marimo style

A reactive notebook fits Nim well if each cell is a module that imports only the cells it reads from,
so that the dependency graph is the import graph.

**What marimo does (Python).** Each cell is a function in a plain `.py` file. Static analysis finds which globals
each cell defines and which it reads, which gives a dependency graph. Editing a cell re-runs every cell that depends on it.
Deleting a cell deletes its variables, so there is no hidden state. Each global is defined in exactly one cell.
UI elements are values in the graph, so moving a slider re-runs the cells that use it.

**Pluto.jl (Julia) is the closer model** for a compiled language. It works the same way, but the notebook is saved
as a valid `.jl` script in dependency order, code runs in a separate worker process,
and a redefined `struct` moves the notebook to a fresh module.

How it maps onto Nim:

- **File format**: a plain `.nim` file with cell markers, saved in dependency order so that `nim c notebook.nim` just works.
  This is close to nimib, so "reactive nimib" is one possible framing.
- **Finding dependencies**: Nim declarations are explicit (`let`, `var`, `const`, `proc`, `type`),
  so parsing alone shows what a cell defines. Finding what a cell reads works better after the compiler's semantic check,
  because of overloads, templates and method-call syntax. IC's symbol data, which `nim track` uses, could give both.
  Cells where a macro creates definitions are the hard case, and should be handled conservatively.
- **One definition per variable**: Nim already forbids redefining a name in the same scope.
- **Execution**: each cell's code goes in a `proc runCell*()`, and the variables it defines stay as module globals.
  The worker (the HCR host) keeps all the globals. After an edit it recompiles the changed modules, reloads them,
  and calls `runCell` on the affected cells in dependency order. When a type changes, or anything else HCR can't reload,
  it restarts the worker and re-runs everything, as Pluto does.
- **Code edits vs widget changes**: editing code needs a recompile. Moving a widget only changes a value,
  so it just re-runs the dependent cells' `runCell` procs, with no compile. That keeps sliders responsive even though Nim is compiled.
- **Running as an app**: Nim's JS backend could compile a finished notebook, with its dependency graph,
  into JavaScript that runs in the browser with no server. Marimo does this with Pyodide (WASM).
- **Same server**: the notebook is the engine from the previous section plus a few notebook calls:
  `cell/update`, `cell/delete`, `graph` and `ui/set`. Outputs are sent as MIME bundles (text, HTML, images), the way Jupyter sends them.

## Open questions and next steps

Open questions:

- Does HCR work with zig cc, the C compiler that nimlang ships? Only gcc was tested.
- Can parsing alone find a cell's dependencies accurately, or is the compiler's semantic check needed?
- Can HCR and IC be combined (`nim ic --hotCodeReloading:on`)? They were tested separately.
- Does `nlvm r` keep state across lines? Its README doesn't say.
- How should a compile error be shown when it comes from a cell's dependency rather than the cell itself?

Next steps:

- [ ] Build the engine library with the re-run backend, plus the stdio server and a terminal client
- [ ] Turn the HCR cells experiment into the HCR backend (export rewriting, `except` imports, value display)
- [ ] Test HCR with zig cc, and HCR together with IC
- [ ] Ask arnetheduck about `nlvm r` state
- [ ] Prototype the dependency analysis for the reactive notebook

## Sources

- [uv add nimlang and other scientific Nim experiments](https://forum.nim-lang.org/t/14230), Nim forum: Araq's and arnetheduck's posts
- [Merry christmas! Progress report on IC](https://forum.nim-lang.org/t/13585), Nim forum, Dec 2025 to Sept 2026
- [Compile with ic:on](https://forum.nim-lang.org/t/14255), Nim forum, Oct 2026
- [nlvm](https://github.com/arnetheduck/nlvm), [INim](https://github.com/inim-repl/INim), [jupyternim](https://github.com/stisa/jupyternim)
- [Hot code reloading](https://nim-lang.org/docs/hcr.html), [NimScript](https://nim-lang.org/docs/nims.html), [compiler user guide](https://nim-lang.org/docs/nimc.html)
- marimo, Pluto.jl, evcxr, nREPL, xeus and LSP are described from general knowledge; their docs were not opened during this research.

Forum threads were read through [tomd](https://github.com/pietroppeter/tomd):
`https://tomd.pietroppeter.xyz/https://forum.nim-lang.org/t/<id>` returns a thread as Markdown.
"""

nbSave
