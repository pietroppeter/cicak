## Renders bench/DESIGN.md as bench/design.html, in the dev log's theme, so the
## design doc can sit next to the results page.
##
##   nim r bench/design.nim

import std/[os, strutils]
import nimib
import ../docs/theme

let benchDir = currentSourcePath().parentDir
var md = readFile(benchDir / "DESIGN.md")
# the title becomes the page header
let lines = md.splitLines
if lines.len > 0 and lines[0].startsWith("# "): md = lines[1 .. ^1].join("\n")
# a link to the results page works next to it
md = md.replace("rendered by `bench/results.nim`", "rendered by `bench/results.nim` ([results page](results.html))")

nbInit
nb.title = "cicak benchmark: design"
nb.doc.filename = benchDir / "design.html"
nb.useTheme(
  titleHtml = "Benchmark <em>design</em>",
  eyebrow = "cicak benchmark",
  epigraph = "What the benchmark measures, and why it is set up this way.",
  meta = "source: bench/DESIGN.md",
  summary = "Design and decisions of the cicak benchmark.",
)
nbText: md
nbSave
