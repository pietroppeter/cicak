# Tasks, run as `nim <task>` (no nimble needed; dependencies come from atlas, see nim.cfg).

task docs, "Render the site: the posts in docs/blog, the index, the benchmark pages":
  exec "nim r --hints:off docs/all.nim"  # one program, see docs/all.nim

task specview, "Render the OpenSpec review page to specview.html, with file diffs against origin/main":
  exec "nim r --hints:off tools/specview.nim --base:origin/main"
