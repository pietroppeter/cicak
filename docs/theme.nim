## The dev-log theme: the nanuq theme (github.com/pietroppeter/nanuq) with a
## green palette, light and dark, self-contained apart from Google Fonts and
## highlight.js for shell snippets.
##
## Usage, right after `nbInit`:
##   nb.useTheme(titleHtml = "...", eyebrow = "...", epigraph = "...", meta = "...")

import std/[json, strformat]
import nimib

const
  projectName* = "cicak"
  repoUrl* = "https://github.com/pietroppeter/cicak"

const themeHead = """
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Familjen+Grotesk:wght@500;700&family=Literata:ital,opsz,wght@0,7..72,400;0,7..72,600;1,7..72,400&family=JetBrains+Mono:wght@400;600&display=swap">
<link rel="icon" href="data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size=%2280%22>🌱</text></svg>">
<style>
/* Layout: one reading column on a pale green ground; code and output read as a notebook cell pair. */
:root {
  --ground: #f2f7f3;     /* page ground */
  --leaf: #ffffff;       /* code surface */
  --ink: #13261b;        /* text */
  --mute: #5a6f62;       /* secondary text */
  --rule: #d2e2d7;       /* borders */
  --moss: #1e7a4c;       /* accent */
  --out-bg: #e6f0e9;     /* output surface */
  --kw: #8a3b8f; --str: #2c6e86; --num: #a55310; --com: #7c8c82; --fn: #1e7a4c;
  --display: "Familjen Grotesk", "Helvetica Neue", Arial, sans-serif;
  --body: "Literata", Georgia, "Times New Roman", serif;
  --mono: "JetBrains Mono", ui-monospace, "SF Mono", Menlo, Consolas, monospace;
  color-scheme: light;
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    --ground: #0d1711; --leaf: #121f17; --ink: #e2efe6; --mute: #93ab9b; --rule: #21362a;
    --moss: #5fd39a; --out-bg: #0a130d;
    --kw: #d79be0; --str: #7fc6dd; --num: #f0a868; --com: #6d8576; --fn: #5fd39a;
    color-scheme: dark;
  }
}
:root[data-theme="dark"] {
  --ground: #0d1711; --leaf: #121f17; --ink: #e2efe6; --mute: #93ab9b; --rule: #21362a;
  --moss: #5fd39a; --out-bg: #0a130d;
  --kw: #d79be0; --str: #7fc6dd; --num: #f0a868; --com: #6d8576; --fn: #5fd39a;
  color-scheme: dark;
}
* { box-sizing: border-box; }
body {
  margin: 0; background: var(--ground); color: var(--ink);
  font: 17px/1.65 var(--body);
  padding-left: max(16px, env(safe-area-inset-left, 0px));
  padding-right: max(16px, env(safe-area-inset-right, 0px));
}
body > header, body > main, body > footer { max-width: 46rem; margin: 0 auto; }
body > header { padding-block: 3rem 0; }
body > footer { padding-block: 1rem 4rem; }
.mast { display: grid; gap: .6rem; padding-bottom: 2rem; border-bottom: 1px solid var(--rule); margin-bottom: 1rem; }
.eyebrow { font: 600 .75rem/1 var(--mono); letter-spacing: .12em; text-transform: uppercase; color: var(--moss); }
.mast h1 { font: 700 clamp(2.4rem, 7vw, 3.6rem)/1.02 var(--display); letter-spacing: -.02em; margin: 0; text-wrap: balance; }
.mast h1 em { font-style: normal; color: var(--moss); }
.epigraph { font-style: italic; color: var(--mute); margin: 0; }
.meta { font: .8rem/1.4 var(--mono); color: var(--mute); }
h2, h3 { font-family: var(--display); text-wrap: balance; line-height: 1.15; }
h2 { font-size: 1.7rem; font-weight: 700; margin: 2.8rem 0 .6rem; letter-spacing: -.01em; }
h3 { font-size: 1.2rem; font-weight: 700; margin: 2rem 0 .4rem; }
p, li { max-width: 65ch; }
a { color: var(--moss); text-underline-offset: 2px; }
a:focus-visible { outline: 2px solid var(--moss); outline-offset: 2px; border-radius: 2px; }
code, pre { font-family: var(--mono); }
pre, pre *, code { font-variant-ligatures: none !important; } /* show >= as typed */
code { font-size: .86em; }
p code, li code { background: var(--out-bg); padding: .1em .3em; border-radius: 3px; }
pre { margin: 0; overflow-x: auto; }
pre:has(> code) {
  position: relative; background: var(--leaf); border: 1px solid var(--rule);
  border-radius: 6px; padding: 1.6rem 1rem .9rem; margin: 1.2rem 0 0; font-size: .85rem; line-height: 1.55;
}
pre:has(> code)::before {
  position: absolute; top: .45rem; right: .7rem;
  font: 600 .65rem/1 var(--mono); letter-spacing: .1em; text-transform: uppercase; color: var(--mute);
}
pre:has(> code.nohighlight.nim)::before { content: "nim · ran"; }
pre:has(> code.language-nim)::before { content: "nim"; }
pre:has(> code.language-sh)::before { content: "shell"; }
pre:has(> code:not([class]))::before { content: "layout"; }
pre:has(> code.nim-source)::before { content: "nim · source of this page"; }
pre:has(> code:not([class])) { background: transparent; border-style: dashed; }
pre:has(> code.nohighlight.nim):has(+ pre.nb-output) { border-radius: 6px 6px 0 0; }
pre.nb-output {
  background: var(--out-bg); border: 1px solid var(--rule); border-top: none; border-radius: 0 0 6px 6px;
  padding: 1.6rem 1rem .9rem; position: relative;
  font: .8rem/1.2 var(--mono); color: var(--ink); white-space: pre;
}
pre.nb-output::before {
  content: "output"; position: absolute; top: .55rem; left: 1rem;
  font: 600 .65rem/1 var(--mono); letter-spacing: .1em; text-transform: uppercase; color: var(--moss);
}
.hljs-keyword, .hljs-meta, .hljs-built_in { color: var(--kw); }
.hljs-string, .hljs-char { color: var(--str); }
.hljs-number, .hljs-literal { color: var(--num); }
.hljs-comment { color: var(--com); font-style: italic; }
.hljs-title, .hljs-function, .hljs-type { color: var(--fn); }
.hljs-attribute, .hljs-symbol, .hljs-variable { color: var(--ink); }
figure { margin: 1.2rem 0; }
figure img { display: block; max-width: 100%; height: auto; border: 1px solid var(--rule); border-radius: 6px; }
figcaption { font: .8rem/1.4 var(--mono); color: var(--mute); margin-top: .4rem; }
blockquote { border-left: 3px solid var(--moss); margin: 1rem 0; padding-left: 1rem; color: var(--mute); }
ul { padding-left: 1.2rem; }
/* wide tables scroll inside themselves, never the page */
table { display: block; overflow-x: auto; border-collapse: collapse; margin: 1.2rem 0; font-size: .85rem; line-height: 1.45;
  border: 1px solid var(--rule); border-radius: 6px; background: var(--leaf); }
th, td { text-align: left; vertical-align: top; padding: .55rem .7rem; border-bottom: 1px solid var(--rule); min-width: 9rem; }
th { font: 600 .68rem/1.2 var(--mono); letter-spacing: .08em; text-transform: uppercase; color: var(--mute); background: var(--out-bg); }
tr:last-child td { border-bottom: none; }
td code { background: var(--out-bg); padding: .1em .3em; border-radius: 3px; }
/* the dev-log index */
ol.posts { list-style: none; padding: 0; margin: 2rem 0; }
ol.posts li { padding: 1rem 0; border-bottom: 1px solid var(--rule); }
ol.posts li:last-child { border-bottom: none; }
ol.posts time { display: block; font: .72rem/1.4 var(--mono); letter-spacing: .06em; color: var(--mute); text-transform: uppercase; }
ol.posts a { font: 700 1.25rem/1.3 var(--display); color: var(--ink); text-decoration: none; }
ol.posts a:hover { color: var(--moss); }
ol.posts p { margin: .3rem 0 0; color: var(--mute); }
/* "Show source": the page's own nimib source, folded at the end */
details.source { margin-top: 3rem; }
details.source summary { cursor: pointer; width: max-content; font: 600 .75rem/1 var(--mono); letter-spacing: .06em;
  text-transform: uppercase; color: var(--moss); padding: .5rem .8rem; border: 1px solid var(--rule); border-radius: 6px; background: var(--leaf); }
details.source summary::marker { content: ""; }
details.source summary::before { content: "Show source"; }
details.source[open] summary::before { content: "Hide source"; }
details.source pre { margin-top: 1rem; }
footer .foot { margin-top: 3rem; padding-top: 1rem; border-top: 1px solid var(--rule); font: .8rem/1.5 var(--mono); color: var(--mute); }
</style>
"""

const themeScripts = """
<script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/languages/bash.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/languages/nim.min.js"></script>
<script>
  if (window.hljs) document.querySelectorAll("code.language-sh, code.language-nim").forEach(el => {
    try { hljs.highlightElement(el); } catch (e) {}
  });
</script>
"""

func themeHeader(blk: JsonNode, nb: Nb): string =
  let c = nb.doc.context
  let (eyebrow, title, epigraph, meta) = (c{"eyebrow"}.getStr, c{"title_html"}.getStr,
                                          c{"epigraph"}.getStr, c{"meta"}.getStr)
  &"""<header class="mast">
  <span class="eyebrow">{eyebrow}</span>
  <h1>{title}</h1>
  <p class="epigraph">{epigraph}</p>
  <span class="meta">{meta}</span>
</header>"""

func themeFooter(blk: JsonNode, nb: Nb): string =
  ## Ends with a folded "Show source" section, like nimib's default theme.
  let source = nb.doc.context{"source_highlighted"}.getStr
  "<footer>" & (if source.len == 0: "" else:
    """<details class="source"><summary></summary><pre><code class="nim-source">""" & source &
    "</code></pre></details>\n") &
  """<div class="foot">Made with <a href="https://github.com/pietroppeter/nimib">nimib</a>.
Blocks marked "nim · ran" were executed when this page was built.
Source: <a href="""" & repoUrl & """">""" & projectName & """</a>.</div></footer>""" & themeScripts

func emptyPartial(blk: JsonNode, nb: Nb): string = ""

proc escapeAttr(s: string): string =
  for c in s:
    case c
    of '&': result.add "&amp;"
    of '"': result.add "&quot;"
    of '<': result.add "&lt;"
    of '>': result.add "&gt;"
    else: result.add c

proc useTheme*(nb: var Nb, titleHtml, eyebrow, epigraph, meta: string, summary = "") =
  ## `titleHtml` may contain `<em>` for the accented word. `summary` is the
  ## one-line description the dev-log index shows for the page.
  let description =
    if summary.len > 0: "<meta name=\"description\" content=\"" & escapeAttr(summary) & "\">\n"
    else: ""
  nb.doc.context["stylesheet"] = %(description & themeHead)
  nb.doc.context["highlight"] = %""
  nb.doc.context["nb_style"] = %""
  nb.doc.context["disableHighlightJs"] = %true
  nb.doc.context["title_html"] = %titleHtml
  nb.doc.context["eyebrow"] = %eyebrow
  nb.doc.context["epigraph"] = %epigraph
  nb.doc.context["meta"] = %meta
  nb.backend.partials["header"] = themeHeader
  nb.backend.partials["footer"] = themeFooter
  nb.backend.partials["left"] = emptyPartial
  nb.backend.partials["right"] = emptyPartial
