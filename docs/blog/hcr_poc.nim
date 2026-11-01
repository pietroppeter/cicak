import nimib
import std/[os, osproc, strutils]
import ../theme

nbInit
nb.title = "PoC: cells as modules with hot code reloading"
nb.doc.filename = nb.doc.filename.parentDir / "2026-10-31-hcr-poc.html"
nb.useTheme(
  titleHtml = "Cells as modules with <em>hot code reloading</em>",
  eyebrow = "dev log · 31 October 2026",
  epigraph = "A running Nim process receives new cells without restarting, and earlier state survives.",
  meta = "proof of concept · Nim 2.4.0 built from source, gcc, Linux · rendered with nimib",
  summary = "First proof of concept: new cell modules are loaded into a running process with hot code reloading, and earlier globals keep their values.",
)

nbText: """
**Result:** a running Nim process can receive new "cells" (small Nim modules) without restarting.
Each new cell runs its top-level code once, can use everything earlier cells defined,
and the values of earlier variables survive. Adding a cell costs about 1 s of compilation with `nim c`,
and about 0.4 s with incremental compilation (`nim ic`), measured separately.

This is the core mechanism of the REPL design in [the research post](2026-10-31-research.html):
each REPL input becomes a module, and the long-running process is the session.
It is a mechanism test, not a REPL yet: the cells are written by hand and there is no prompt.

## The pieces

Hot code reloading (HCR, `--hotCodeReloading:on`) compiles every module to its own shared library.
The main module is the one part that can't be reloaded, so it is a fixed driver:
it waits for a `go` file to appear, then calls `performCodeReload()`, twice.
"""

nbFile "../experiments/hcr-cells/main.nim"

nbText: """
`main` imports `cells`, a module whose only job is to import every cell so far.
At the start it imports just `c1`; the script rewrites it to `import c1, c2` and then `import c1, c2, c3`.
This is the file a REPL would regenerate after each input.

The cells are ordinary modules. Their exported (`*`) symbols are what later cells can see,
so a REPL would add the `*` when it turns an input into a module.
"""

nbFile "../experiments/hcr-cells/c1.nim"
nbFile "../experiments/hcr-cells/c2.nim"
nbFile "../experiments/hcr-cells/c3.nim"

nbText: """
`c3` assigns to `x`, a variable owned by `c1`, and reads `y`, owned by `c2`.

## Running it

[`run.sh`](https://github.com/pietroppeter/cicak/blob/main/experiments/hcr-cells/run.sh)
builds the two runtime libraries HCR needs (`libnimrtl.so` and `libnimhcr.so`),
compiles the host with only `c1`, and starts it in the background.
Then it adds `c2`, recompiles, and touches `go`; then the same for `c3`.
"""

nbFile "../experiments/hcr-cells/run.sh"

nbText: """
The output below was captured when this page was built, by running the script above.
"""

nbCode:
  let (output, exitCode) = execCmdEx("sh ../experiments/hcr-cells/run.sh")
  echo output.strip
  echo "exit code: ", exitCode

nbText: """
What the output shows:

- `c1 init, x=41` is printed once, at startup. Neither reload runs `c1` again.
- After the first reload, `c2` runs for the first time and sees `x` from `c1` (`y = 42`).
- After the second reload, `c3` changes `x` to 100. `y` is still 42: `c2` was not re-run,
  so its value is the one computed earlier, and `twice` from `c2` is callable from `c3`.

That is the behaviour a REPL session needs: earlier inputs never re-run, and their state stays.
INim, by contrast, re-runs every earlier input each time.

## Cost of adding a cell

Recompiling the host after adding a cell took about 1.05 s with `nim c` (gcc, warm cache).
[`experiments/ic-chain`](https://github.com/pietroppeter/cicak/tree/main/experiments/ic-chain)
measures the same step with `nim ic` on a chain of 20 cell modules, each importing and re-exporting the previous one.
It hasn't been combined with HCR yet, so this is a separate number.
Its script:
"""

nbFile "../experiments/ic-chain/run.sh"

nbText: """
Its output, captured when this page was built:
"""

nbCode:
  let (icOutput, icExit) = execCmdEx("sh ../experiments/ic-chain/run.sh")
  for line in icOutput.strip.splitLines:
    if not line.startsWith("files in"):
      echo line
  echo "exit code: ", icExit

nbText: """
The first `nim ic` builds the stdlib and all 20 cells into the IC cache.
After that, adding a 21st cell only checks and compiles the new module.

## What happened on Nim 2.2.6

The same host crashed at startup with a segfault on Nim 2.2.6 (the version the `nimlang` package currently ships):
the generated main module never initialised its HCR function pointers.
This happened with orc and refc, threads on and off. On 2.4.0 it works with the defaults.

## Not covered yet

- **Generating cells from input**: adding `*` to top-level declarations, writing `cells.nim`,
  and `import cell_K except x` when a later cell redefines a name.
- **Showing values** of bare expressions (`>>> x` printing value and type).
- **HCR together with IC**: the 1 s above is `nim c`; whether `nim ic --hotCodeReloading:on` works hasn't been tried.
- **Other C compilers**: only gcc. nimlang ships zig cc.
- **Limits of HCR**: changing a type defined in an earlier cell can't be reloaded,
  and under orc each reload keeps the old library loaded, so memory grows over a long session.
- **The host executable**: the running `host` can't be overwritten while it runs ("Text file busy"),
  so the script writes the recompiled one to `host.next`. Only the cell libraries matter for the reload.
"""

nbSave
