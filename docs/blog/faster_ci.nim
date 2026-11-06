import nimib
import std/os
import ../theme

nbInit
nb.title = "Faster CI"
nb.doc.filename = nb.doc.filename.parentDir / "2026-11-06-faster-ci.html"
nb.useTheme(
  titleHtml = "Faster <em>CI</em>",
  eyebrow = "dev log · 6 November 2026",
  epigraph = "From about 9 minutes to 1: no Nim build, and one program for the whole site.",
  meta = "CI · GitHub Actions · rendered with nimib",
  summary = "The site's CI job went from about 9 minutes to 1: Nim comes from the release tarball instead of a build from source, and the whole site renders in one program. Two tricks learned in nanuq.",
)

nbText: """
The CI job that renders this site (the posts, the index and the benchmark pages) and
publishes it to GitHub Pages had become slow: the merge of PR #12 took **8 min 50 s**.
Two tricks, both learned in [nanuq](https://github.com/pietroppeter/nanuq), brought it
down to about **1 minute**.

## Where the time went

| Step | Before | After |
|---|---|---|
| Nim | 7 min 20 s (built from source) | 2 s (release tarball, cached) |
| Render the site | ~70 s (seven programs) | 26 s (one program) |
| Whole job | 8 min 50 s | 1 min |

**Nim.** `nim ic` needs `nifler` and `nifmake`, which the first 2.4.0 release
binaries did not ship, so CI built the `version-2-4` branch from source. The build
was cached by the branch's commit, which meant a full rebuild every time the branch
moved. Since its rebuild of 28 October the official linux_x64 tarball ships both
tools, and it is what the cloud sessions already use. CI now downloads it, checks its
sha256 and caches it by that sha256. The only extra is `musl`, which the tarball's
`nifler` and `nifmake` are linked against.

**One program.** Each page was its own `nim r`: seven times the Nim frontend, the C
compiler and the linker for nimib and its dependencies. Now `nim docs` runs
`docs/all.nim`, which imports every page, so they compile and link once. Each page
renders when its module is initialised, in import order, and the posts are found at
compile time, so a new post needs no list. A single page still renders on its own
with `nim r docs/blog/<post>.nim`.
"""

nbFile "all.nim"

nbText: """
## What is not cached

Nim's own build cache (`~/.cache/nim`) is not kept between runs, although that would
save a few more seconds. The [PoC post](2026-10-31-hcr-poc.html) runs its experiments
when it renders, and one of them times a cold `nim ic` build: with a warm cache the
"cold" time dropped from 5.7 s to 2.7 s.
"""
nbSave
