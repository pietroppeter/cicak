import nimib
import std/os
import ../theme

nbInit
nb.title = "What the first benchmark runs say"
# dated slug for the dev log
nb.doc.filename = nb.doc.filename.parentDir / "2026-11-06-bench-results.html"
nb.useTheme(
  titleHtml = "What the first <em>benchmark</em> runs say",
  eyebrow = "dev log · 6 November 2026",
  epigraph = "How long a Nim REPL makes you wait, cell by cell: the Nim frontend is most of it, nim ic pays off after a few cells, and hot reload wins when earlier cells are expensive.",
  meta = "benchmark · rendered with nimib",
  summary = "Reading the first runs of the cicak benchmark: where the time goes, when nim ic and hot reload pay off, and how far we are from a snappy REPL.",
)

# The charts are screenshots of the results page as it was on 6 November 2026, kept
# next to the post (blog/bench-results/), so the post keeps showing what it describes
# when new runs change the live page.
nbRawHtml: """<style>
.shot { margin: 1.2rem 0 1.6rem; }
.shot img { display: block; width: 100%; height: auto; border: 1px solid var(--rule); border-radius: 6px; }
.shot figcaption { font-size: .85rem; color: var(--mute); margin-top: .4rem; }
</style>"""

proc shot(file, caption: string) =
  nbRawHtml: "<figure class=\"shot\"><a href=\"bench-results/" & file & "\"><img src=\"bench-results/" &
    file & "\" alt=\"" & caption & "\" loading=\"lazy\"></a><figcaption>" & caption & "</figcaption></figure>"

nbText: """
The [benchmark](../bench/results.html) adds the cells of a scenario to a session one at a
time, as someone using a REPL would, and times each one in every way cicak could compile
and run them: `nim c` or `nim ic` (incremental compilation), and re-running the whole
program or hot reloading the new cell into a long-running host. It does this in debug and
release builds (and danger, for the heavy computation), over four scenarios: integer
variables (s0), learning `std/tables` (s1), exploring arraymancer (s2), and exploring the
result of a heavy computation (s3). Why it is set up this way is in the
[design](../bench/design.html), and every cell is on the [scenarios](../bench/scenarios.html) page.

Those three pages are living documents: they change with every run and every change to
the benchmark. This post is a snapshot. It reads the runs of 1 November 2026, on a cloud
session (4 cores, 5 repetitions; s0 was rerun that evening with interacting variables),
and the charts below are screenshots of the results page as it was on 6 November.

## The Nim frontend is most of the wait

Each bar is one cell, split into the time spent in the Nim compiler itself (blue), the
C compiler, the link and running the program or reloading the cell. Here is learning
`std/tables` in debug:
"""
shot "s1-phases-debug.png", "s1, learning std/tables, debug: time per cell by phase, for each mode that works (nim ic with hot reload fails)."

nbText: """
In nearly every cell, in every mode, blue is the largest part. Speeding up a cell means
speeding up semantic checking, more than C compilation. `nim ic` has spikes where a cell
pulls in a new part of the standard library (cell 14 here), and after them it settles
back to the cheapest per cell.

## `nim ic` costs more to start and less per cell

The total wait so far, after each cell, for integer variables:
"""
shot "s0-cumulative.png", "s0, integer variables: total wait so far after each cell (median, with the min-max band)."
nbText: """
Cell 0 (compiling and starting an empty program) takes about 4 to 5 s with `nim ic` in
debug and 6 to 6.5 s in release, against 1.2 s and 2.2 s with `nim c`. After that `nim ic`
is the cheapest per cell: 0.67 s against 0.86 s for integer variables. The lines cross, so
`nim ic` overtakes `nim c` after 5 to 12 cells, depending on the scenario. For `std/tables`
the gap is wider, especially in release (0.9 s against 2.6 s per cell):
"""
shot "s1-cumulative.png", "s1, learning std/tables: total wait so far after each cell."

nbText: """
## Hot reload wins when earlier cells are expensive to run

Re-running the program runs every earlier cell again. That is fine for cheap cells, and
expensive when one of them does real work, as in s3, where cell 2 runs a particle
simulation:
"""
shot "s3-cumulative.png", "s3, a heavy computation explored over 20 cells: total wait so far after each cell."
nbText: """
Re-running costs 101 s in debug over the session (93 s with `nim ic`); hot reload, which
runs the simulation once, costs 34 s. A release build makes the computation faster, so
re-running drops to 57 s (49 s with `nim ic`), but hot reload stays ahead, and once it has
run the computation once, its release build has nothing left to gain. Danger is about the
same as release. For cheap cells, hot reload with `nim c` costs about the same per cell as
re-running.

## Release builds mostly add C compile time

Over a whole session (each panel is one scenario, with its own scale), release builds are
slower everywhere except where a computation dominates:
"""
shot "whole-session.png", "Median time of a whole session, stacked by phase, one panel per scenario."
nbText: """
`std/tables` goes from 29 s to 50 s with `nim c` when built in release. For a REPL, debug
is the better default, and release is for the cells that compute something heavy.

## How far from snappy

The measure we care about most is how long a cell takes once a session is under way: the
mean over cells 11 to 20. Under 1 s (the dotted line) a REPL feels snappy.
"""
shot "snappy.png", "Mean time per cell over cells 11 to 20, per scenario, build mode and mode (median over repetitions, whiskers from the fastest to the slowest)."
nbText: """
Only the simplest cells get there. Integer variables are under 1 s in every mode, fastest
with `nim ic` (0.56 s). Learning `std/tables` comes closest with `nim ic` in debug (1.1 s).
The heavy-computation scenario stays at 1.4 s at best (hot reload), and arraymancer at
about 7 s per cell, mostly in the Nim frontend.

## What does not work yet

- `nim ic` crashes on arraymancer (a segfault in `nim m`), so the incremental modes fail
  at its cell 1.
- `nim ic` with hot reload fails in every scenario, at the link step of cell 0. It stays in
  the benchmark, so the results will show when it starts working.
- Where a session completed, the outputs agree across modes.

## What next

The numbers point at the same place: a REPL session spends its time in the Nim frontend,
so the most promising mode is incremental compilation with hot reload, which does not link
yet on Nim 2.4. Until then, `nim ic` with re-run is the fastest per cell for cheap cells,
and `nim c` with hot reload for sessions that compute something. Next runs will add other
environments (other machines, through Docker) and compare them after calibration; the
[results page](../bench/results.html) will show them as they come.
"""

nbSave
