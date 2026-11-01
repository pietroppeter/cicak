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
state. These posts follow its development, newest first. The code is on
[GitHub](""" & repoUrl & """).
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
