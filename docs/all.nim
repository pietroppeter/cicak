## Renders the whole site in one program: every dev-log post (docs/blog/*.nim), then
## the index, then the benchmark pages (bench/results.nim, design.nim, scenarios_page.nim,
## from the committed results). One compile and one link instead of one per page.
##
##   nim docs                          # the whole site (runs this file)
##   nim r docs/blog/hcr_poc.nim       # one post, as before
##
## Each page renders when its module is initialised, in import order: posts by file
## name, then the index (it lists the rendered posts), then the benchmark pages.
## Posts are found at compile time, so a new one needs no list here.

import std/[macros, os, strutils, algorithm]

macro importPages(): untyped =
  let dir = currentSourcePath().parentDir
  var posts: seq[string]
  for line in staticExec("ls " & quoteShell(dir / "blog")).splitLines:
    if line.endsWith(".nim"): posts.add line[0 ..< ^4]
  posts.sort
  var src = ""
  # absolute paths: parseStmt has no file to be relative to
  for p in posts: src.add "import \"" & dir / "blog" / p & "\"\n"
  src.add "import \"" & dir / "index" & "\"\n"
  for p in ["results", "design", "scenarios_page"]:
    src.add "import \"" & dir.parentDir / "bench" / p & "\"\n"
  result = parseStmt(src)

{.warning[UnusedImport]: off.}
importPages()
