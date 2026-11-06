## The dev-log index: lists the rendered posts in docs/blog, newest first.
## Render the posts first; nothing here needs editing when a post is added.
import nimib
import std/[os, algorithm, re, strutils, times]
import theme

nbInit
nb.title = projectName & " dev log"
nb.useTheme(
  titleHtml = projectName & " <em>dev log</em>",
  eyebrow = "a REPL for Nim",
  epigraph = "Read, eval, print, loop, and keep the state.",
  meta = "Rendered with nimib",
  summary = "Notes from building a REPL for Nim.",
)

type Post = object
  file, title, summary: string
  date: DateTime

proc unescape(s: string): string =
  s.multiReplace(("&quot;", "\""), ("&#x27;", "'"), ("&lt;", "<"), ("&gt;", ">"), ("&amp;", "&"))

proc escape(s: string): string =
  s.multiReplace(("&", "&amp;"), ("<", "&lt;"), (">", "&gt;"), ("\"", "&quot;"))

proc readPost(path: string): Post =
  ## Date and link from the dated file name, title from `<title>`, summary from
  ## the description meta tag the theme writes.
  let html = readFile(path)
  result.file = path.extractFilename
  result.date = parse(result.file[0 ..< 10], "yyyy-MM-dd")
  var m: array[1, string]
  if html.find(re"<title>([^<]*)</title>", m) >= 0: result.title = m[0].strip.unescape
  if html.find(re"""<meta name="description" content="([^"]*)">""", m) >= 0:
    result.summary = m[0].unescape

var posts: seq[Post]
for path in walkFiles("blog/*.html"):  # nimib runs from docs/ (see nimib.toml)
  if path.extractFilename.match(re"\d{4}-\d{2}-\d{2}-.*\.html"):
    posts.add readPost(path)
posts.sort(proc (a, b: Post): int = cmp(b.file, a.file))

nbText: """
A REPL for Nim, where each input is compiled to native code and the session keeps its
state. The code is on [GitHub](""" & repoUrl & """).

## Living documents

Pages that are kept up to date as the project changes. The posts below are dated
snapshots; these are not.
"""

# the latest benchmark run, from the dated run folders in bench/results
var lastRun = ""
for kind, d in walkDir("../bench/results"):  # nimib runs from docs/
  let name = d.extractFilename
  if kind == pcDir and name.match(re"\d{4}-\d{2}-\d{2}T") and name > lastRun: lastRun = name
let lastRunText = if lastRun.len > 0: "latest run " & parse(lastRun[0 ..< 10], "yyyy-MM-dd").format("d MMM yyyy") else: "no runs yet"

type Living = tuple[href, title, summary, updated: string]
let living: seq[Living] = @[
  ("bench/results.html", "Benchmark results",
   "How long each cell takes in every mode (nim c or nim ic, re-run or hot reload) and build mode.",
   "with every benchmark run (" & lastRunText & ")"),
  ("bench/design.html", "Benchmark design",
   "What the benchmark measures, and why it is set up this way.",
   "when the benchmark changes"),
  ("bench/scenarios.html", "Benchmark scenarios",
   "Every cell of every scenario, as the benchmark adds them.",
   "when a scenario changes"),
  (repoUrl & "/tree/main/openspec/specs", "Specs",
   "How the project behaves today (OpenSpec): CI and the dev log.",
   "when a change is archived"),
  (repoUrl & "/blob/main/BACKLOG.md", "Backlog",
   "Ideas not yet implemented; done ones move to the changelog.",
   "with each idea or change"),
]
var docsTable = "<div class=\"posts-wrap\"><table class=\"posts living\">\n" &
  "<thead><tr><th>Document</th><th>What it is</th></tr></thead>\n<tbody>\n"
for d in living:  # two columns, so the table fits a phone
  docsTable.add "<tr><td class=\"post\"><a href=\"" & d.href & "\">" & escape(d.title) &
    "</a></td>\n<td class=\"summary\">" & escape(d.summary) & "<br><small>Updated " &
    escape(d.updated) & ".</small></td></tr>\n"
docsTable.add "</tbody></table></div>"
nbRawHtml: docsTable

nbText: """
## Posts

Dated posts that follow the development, newest first.
"""

var items = "<div class=\"posts-wrap\"><table class=\"posts\">\n" &
  "<thead><tr><th>Date</th><th>Post</th><th>Summary</th></tr></thead>\n<tbody>\n"
for p in posts:
  items.add "<tr><td class=\"date\"><time datetime=\"" & p.date.format("yyyy-MM-dd") & "\">" &
    p.date.format("d MMM yyyy") & "</time></td>\n<td class=\"post\"><a href=\"blog/" & p.file & "\">" &
    escape(p.title) & "</a></td>\n<td class=\"summary\">" & escape(p.summary) & "</td></tr>\n"
items.add "</tbody></table></div>"
nbRawHtml: items

nbSave
