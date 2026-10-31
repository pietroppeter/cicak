# Tasks, run as `nim <task>` (no nimble needed; dependencies come from atlas, see nim.cfg).
import std/strutils

task docs, "Render the dev log: the posts in docs/blog, then the index":
  for f in listFiles("docs/blog"):
    if f.endsWith(".nim"):
      exec "nim r --hints:off " & f
  exec "nim r --hints:off docs/index.nim"

task specview, "Render the OpenSpec review page to specview.html, with file diffs against origin/main":
  exec "nim r --hints:off tools/specview.nim --base:origin/main"
