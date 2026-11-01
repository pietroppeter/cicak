## The benchmark results page: reads every run in bench/results (or the runs
## given as arguments) and renders bench/results.html with nimib and nim-plotly.
##
##   nim r bench/results.nim [bench/results/<run id> ...]
##
## The page only reads results; it never runs the benchmark (bench/bench.nim does).

import std/[os, json, strutils, strformat, tables, algorithm, sequtils, math, sets]
import nimib
import plotly/[api, plotly_types]
import ../docs/theme

type
  Phase = enum phNim = "Nim", phCc = "C compile", phLink = "link", phRun = "run or reload"
  CellTime = array[Phase, float]          ## ms, summed over the cell's steps
  Key = tuple[scenario, opt, mode: string]
  Session = object
    cells: seq[CellTime]                  ## index = cell number, 0 = start
    okCells: int                          ## cells after 0 that succeeded
    failed: bool
    error, log: string
    failedAt: int
    outputs: seq[string]

const
  modesOrder = ["c+rerun", "ic+rerun", "c+hcr", "ic+hcr"]
  optsOrder = ["debug", "release", "danger"]
  # the validated default categorical palette (dataviz skill), fixed order
  palette = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100"]
  dashes = {"debug": "solid", "release": "dash", "danger": "dot"}.toTable
  modeNames = {"c+rerun": "nim c, re-run all", "ic+rerun": "nim ic, re-run all",
               "c+hcr": "nim c, hot reload", "ic+hcr": "nim ic, hot reload"}.toTable

let benchDir = currentSourcePath().parentDir
var runDirs: seq[string]
for a in commandLineParams():
  if not a.startsWith("-"): runDirs.add a
if runDirs.len == 0:
  for kind, d in walkDir(benchDir / "results"):
    if kind == pcDir and fileExists(d / "meta.json"): runDirs.add d
runDirs.sort

var
  metas: seq[JsonNode]
  sessions: Table[Key, seq[Session]]      ## one per repetition
  titles: Table[string, string]
  cellTitles: Table[string, seq[string]]

for d in runDirs:
  let meta = parseFile(d / "meta.json")
  metas.add meta
  for id, s in meta["scenarios"]:
    titles[id] = s["title"].getStr
    cellTitles[id] = s["cellTitles"].to(seq[string])
  var bySession: OrderedTable[(Key, int), Session]
  for line in lines(d / "steps.jsonl"):
    let r = parseJson(line)
    let k: Key = (r["scenario"].getStr, r["opt"].getStr, r["mode"].getStr)
    let sk = (k, r["rep"].getInt)
    if sk notin bySession: bySession[sk] = Session(failedAt: -1)
    let c = r["cell"].getInt
    var s = addr bySession[sk]
    while s.cells.len <= c: s.cells.add default(CellTime)
    s.cells[c][phNim] += r["nimMs"].getFloat
    s.cells[c][phCc] += r["ccMs"].getFloat
    s.cells[c][phLink] += r["linkMs"].getFloat
    s.cells[c][phRun] += r["runMs"].getFloat
  for line in lines(d / "cells.jsonl"):
    let r = parseJson(line)
    let k: Key = (r["scenario"].getStr, r["opt"].getStr, r["mode"].getStr)
    let sk = (k, r["rep"].getInt)
    if sk notin bySession: bySession[sk] = Session(failedAt: -1)
    var s = addr bySession[sk]
    let c = r["cell"].getInt
    while s.outputs.len <= c: s.outputs.add ""
    s.outputs[c] = r["output"].getStr
    if r["ok"].getBool:
      if c > 0: inc s.okCells
    elif not s.failed:
      s.failed = true
      s.failedAt = c
      s.error = r["error"].getStr
      s.log = r["log"].getStr.strip
  for sk, s in bySession:
    sessions.mgetOrPut(sk[0], @[]).add s

proc median(xs: seq[float]): float =
  if xs.len == 0: return NaN
  let s = xs.sorted
  if s.len mod 2 == 1: s[s.len div 2] else: (s[s.len div 2 - 1] + s[s.len div 2]) / 2

proc total(c: CellTime): float = c[phNim] + c[phCc] + c[phLink] + c[phRun]

proc complete(ss: seq[Session]): seq[Session] = ss.filterIt(not it.failed)

proc sec(ms: float): string =
  if ms.isNaN: "–" else: formatFloat(ms / 1000, ffDecimal, (if ms < 10_000: 2 else: 1))

proc scenariosIn(): seq[string] =
  for k in sessions.keys:
    if k.scenario notin result: result.add k.scenario
  result.sort

proc optsIn(scenario: string): seq[string] =
  for o in optsOrder:
    for m in modesOrder:
      if (scenario, o, m) in sessions and o notin result: result.add o

proc modesIn(scenario, opt: string): seq[string] =
  modesOrder.filterIt((scenario, opt, it) in sessions)

# ---- charts --------------------------------------------------------------

var chartCount = 0
proc chart(traces: seq[JsonNode], layout: JsonNode, height = 380, legendY = -0.18): string =
  ## A plotly chart as HTML; plotly.js comes from cdn.plot.ly (loaded once, in the head).
  inc chartCount
  let id = "chart" & $chartCount
  var lay = layout
  lay["height"] = %height
  lay["margin"] = %*{"l": 56, "r": 16, "t": 36, "b": 48}
  lay["paper_bgcolor"] = %"rgba(0,0,0,0)"
  lay["plot_bgcolor"] = %"rgba(0,0,0,0)"
  lay["font"] = %*{"family": "JetBrains Mono, monospace", "size": 11, "color": "#7c8c82"}
  lay["legend"] = %*{"orientation": "h", "y": legendY, "traceorder": "normal"}
  for ax in ["xaxis", "yaxis", "xaxis2", "yaxis2", "xaxis3", "yaxis3", "xaxis4", "yaxis4"]:
    if ax in lay:
      lay[ax]["gridcolor"] = %"rgba(124,140,130,0.18)"
      lay[ax]["zeroline"] = %false
  &"""<div id="{id}" class="bench-chart"></div>
<script>Plotly.newPlot("{id}", {$ %traces}, {$lay}, {{responsive: true, displayModeBar: false}});</script>"""

proc trace[T](t: Trace[T]): JsonNode =
  ## A nim-plotly trace as plotly.js JSON.
  let p = Plot[T](traces: @[t], layout: Layout())
  p.toPlotJson.traces[0]

proc cumulativeChart(scenario: string): string =
  ## Seconds waited so far after each cell, median over repetitions, with the
  ## min-max band; colour is the mode, dash the build mode.
  var traces: seq[JsonNode]
  for o in optsIn(scenario):
    for mi, m in modesOrder:
      let ss = sessions.getOrDefault((scenario, o, m)).complete
      if ss.len == 0: continue
      let n = ss.mapIt(it.cells.len).min
      var med, lo, hi: seq[float]
      for c in 0 ..< n:
        let cums = ss.mapIt((block:
          var acc = 0.0
          for j in 0 .. c: acc += it.cells[j].total
          acc / 1000))
        med.add median(cums); lo.add cums.min; hi.add cums.max
      let xs = toSeq(0 ..< n).mapIt(it.float)
      let name = modeNames[m] & ", " & o
      var band = trace(Trace[float](`type`: PlotType.Scatter, mode: PlotMode.Lines,
                                    xs: xs & xs.reversed, ys: hi & lo.reversed, name: name))
      band["fill"] = %"toself"
      band["fillcolor"] = %(palette[mi] & "22")
      band["line"] = %*{"width": 0}
      band["hoverinfo"] = %"skip"
      band["showlegend"] = %false
      band["legendgroup"] = %name
      traces.add band
      var line = trace(Trace[float](`type`: PlotType.Scatter, mode: PlotMode.Lines,
                                    xs: xs, ys: med, name: name))
      line["line"] = %*{"color": palette[mi], "width": 2, "dash": dashes[o]}
      line["legendgroup"] = %name
      line["hovertemplate"] = %(name & "<br>cell %{x}: %{y:.1f} s so far<extra></extra>")
      traces.add line
  chart(traces, %*{"title": {"text": "Total wait so far (s)", "x": 0},
                   "xaxis": {"title": {"text": "cell (0 = session start)"}, "dtick": 5},
                   "yaxis": {"title": {"text": "s"}, "rangemode": "tozero"}}, 420)

proc stackedChart(scenario, opt: string): string =
  ## Time per cell, stacked by phase, one panel per mode, shared y axis.
  let ms = modesIn(scenario, opt).filterIt(sessions[(scenario, opt, it)].complete.len > 0)
  if ms.len == 0: return ""
  var traces: seq[JsonNode]
  var lay = %*{"title": {"text": &"Time per cell by phase (s), {opt}", "x": 0},
               "barmode": "stack", "bargap": 0.15,
               "grid": {"rows": ms.len, "columns": 1, "pattern": "independent"}}
  var annotations: seq[JsonNode]
  for i, m in ms:
    let ss = sessions[(scenario, opt, m)].complete
    let n = ss.mapIt(it.cells.len).min
    let ax = if i == 0: "" else: $(i + 1)
    for ph in Phase:
      var ys: seq[float]
      for c in 0 ..< n: ys.add median(ss.mapIt(it.cells[c][ph] / 1000))
      var t = trace(Trace[float](`type`: PlotType.Bar, xs: toSeq(0 ..< n).mapIt(it.float),
                                 ys: ys, name: $ph))
      t["marker"] = %*{"color": palette[ph.ord], "line": {"width": 0}}
      t["xaxis"] = %("x" & ax)
      t["yaxis"] = %("y" & ax)
      t["legendgroup"] = % $ph
      t["showlegend"] = %(i == 0)
      t["hovertemplate"] = %(&"{modeNames[m]}<br>cell %{{x}}, {ph}: %{{y:.2f}} s<extra></extra>")
      traces.add t
    lay["xaxis" & ax] = %*{"dtick": 5, "matches": "x"}
    lay["yaxis" & ax] = %*{"matches": "y", "rangemode": "tozero"}
    annotations.add %*{"text": modeNames[m], "xref": "x" & ax & " domain", "yref": "y" & ax & " domain",
                       "x": 0, "y": 1.12, "showarrow": false, "xanchor": "left",
                       "font": {"size": 11, "color": "#7c8c82"}}
  lay["annotations"] = %annotations
  chart(traces, lay, 140 + 150 * ms.len)

proc totalsChart(opt: string): string =
  ## Median total per scenario and mode, stacked by phase.
  var traces: seq[JsonNode]
  for ph in Phase:
    var xs: seq[string]
    var ys: seq[float]
    for s in scenariosIn():
      for m in modesIn(s, opt):
        let ss = sessions[(s, opt, m)].complete
        if ss.len == 0: continue
        xs.add s & " · " & m
        ys.add median(ss.mapIt(it.cells.mapIt(it[ph]).sum / 1000))
    if xs.len == 0: continue
    var t = trace(Trace[float](`type`: PlotType.Bar, text: xs, ys: ys, name: $ph))
    t["x"] = %xs
    t.delete "text"
    t["marker"] = %*{"color": palette[ph.ord], "line": {"width": 0}}
    t["hovertemplate"] = %(&"%{{x}}<br>{ph}: %{{y:.1f}} s<extra></extra>")
    traces.add t
  if traces.len == 0: return ""
  chart(traces, %*{"title": {"text": &"Whole session, median (s), {opt}", "x": 0},
                   "barmode": "stack", "xaxis": {"tickangle": -40},
                   "yaxis": {"rangemode": "tozero"}}, 480, -0.45)

# ---- checks --------------------------------------------------------------

proc outputMismatches(scenario, opt: string): seq[string] =
  ## Same compiler output check: c and ic agree for each strategy, and the
  ## hot reload outputs of cells 1..k add up to what re-run prints at cell k.
  var reference: Table[string, seq[string]]   # strategy -> outputs by cell (first complete rep)
  for m in modesIn(scenario, opt):
    let strategy = m.split('+')[1]
    for s in sessions[(scenario, opt, m)]:
      if s.outputs.len == 0: continue
      if strategy notin reference:
        reference[strategy] = s.outputs
        continue
      let r = reference[strategy]
      for c in 0 ..< min(r.len, s.outputs.len):
        if (s.failedAt < 0 or c < s.failedAt) and r[c] != s.outputs[c]:
          result.add &"{m}: cell {c} prints something else than the first {strategy} session"
          break
  if "rerun" in reference and "hcr" in reference:
    let (re, hc) = (reference["rerun"], reference["hcr"])
    var acc = ""
    for c in 0 ..< min(re.len, hc.len):
      acc.add hc[c]
      if acc != re[c]:
        result.add &"hot reload and re-run disagree from cell {c}"
        break
  result = result.deduplicate

# ---- the page ------------------------------------------------------------

nbInit
nb.title = "cicak benchmark: results"
nb.doc.filename = benchDir / "results.html"
let last = if metas.len > 0: metas[^1] else: newJObject()
nb.useTheme(
  titleHtml = "Benchmark <em>results</em>",
  eyebrow = "cicak benchmark",
  epigraph = "How long a Nim REPL makes you wait, cell by cell, in each way of compiling and running cells.",
  meta = (if metas.len > 0: &"""{last["nim"].getStr} · {last["cc"].getStr} · {last["machine"]["cpu"].getStr}, {last["machine"]["cores"].getInt} cores · runs: {metas.mapIt(it["run"].getStr).join(", ")}""" else: "no runs yet"),
  summary = "Compile and run times of the cicak benchmark scenarios in each mode.",
)
nb.doc.context["stylesheet"] = %(nb.doc.context["stylesheet"].getStr & "\n<script src=\"https://cdn.plot.ly/plotly-2.35.2.min.js\"></script>\n<style>.bench-chart{width:100%;margin:1rem 0 2rem}</style>")

nbText: """
Design and decisions: [bench/DESIGN.md](https://github.com/pietroppeter/cicak/blob/main/bench/DESIGN.md).
Times are medians over repetitions; bands and ranges show min and max. Cell 0 is the session start
(compiling `system` and, for hot reload, starting the host); it is counted in every total.
Modes: `c` or `ic` is the compiler (`nim c`, `nim ic`), `rerun` re-runs the whole program for each
cell, `hcr` hot reloads the new cell into a running host.
"""

nbText: """
## Findings of the first run

From the cloud run of 1 November 2026 (5 repetitions; the numbers are in the tables below).
When later runs are added, check these against them.

- **The Nim frontend is most of the wait.** In nearly every cell the blue part is the largest,
  in every mode. Speeding up a cell means speeding up semantic checking, more than C.
- **`nim ic` costs more to start and less per cell.** Cell 0 takes about 3.9 s in debug
  and 6 s in release, against 1.2 s and 2.2 s with `nim c`. After that it is the cheapest
  per cell: 0.67 s against 0.89 s for integer variables, and 0.9 s against 2.6 s for
  `std/tables` in release. It overtakes `nim c` after about ten cells.
- **Hot reload wins when earlier cells are expensive to run.** In s3, re-running costs
  101 s in debug (93 s with `nim ic`), and hot reload costs 34 s. For cheap cells, hot reload
  with `nim c` costs about the same per cell as re-running.
- **Release builds mostly add C compile time.** `std/tables` goes from 29 s to 50 s with
  `nim c`. Only the heavy computation gains, and in hot reload mode, where it runs once,
  that gain is cancelled out. Danger is about the same as release.
- **Arraymancer costs about 6 s per cell**, mostly Nim, in every mode that works. `nim ic`
  crashes on it (segfault in `nim m`), so the incremental modes fail at cell 1.
- **`nim ic` with hot reload fails** in every scenario, at the link step of cell 0.
- The outputs agree across modes wherever a session completed.
"""

proc summaryTable(s: string): string =
  result = "| build | mode | cells ok | cell 0 (s) | per cell (s) | total (s), min–max |\n|---|---|---|---|---|---|\n"
  for o in optsIn(s):
    for m in modesIn(s, o):
      let all = sessions[(s, o, m)]
      let ss = all.complete
      let n = cellTitles.getOrDefault(s).len
      let okCells = all.mapIt(it.okCells).min
      if ss.len == 0:
        result.add &"| {o} | {m} | {okCells}/{n} | – | – | fails |\n"
        continue
      let c0 = median(ss.mapIt(it.cells[0].total))
      let perCell = median(ss.mapIt(it.cells[1 .. ^1].mapIt(it.total)).concat)
      let totals = ss.mapIt(it.cells.mapIt(it.total).sum)
      result.add &"| {o} | {m} | {okCells}/{n} | {sec(c0)} | {sec(perCell)} | {sec(median(totals))}, {sec(totals.min)}–{sec(totals.max)} |\n"

for o in optsOrder:
  let html = totalsChart(o)
  if html.len > 0: nbRawHtml: html

for s in scenariosIn():
  nbText: &"## {s}: {titles.getOrDefault(s, s)}\n\n" & summaryTable(s)
  nbRawHtml: cumulativeChart(s)
  for o in optsIn(s):
    let html = stackedChart(s, o)
    if html.len > 0: nbRawHtml: html
  # failures and output checks
  var notes = ""
  for o in optsIn(s):
    for m in modesIn(s, o):
      let failed = sessions[(s, o, m)].filterIt(it.failed)
      if failed.len > 0:
        let f = failed[0]
        let lastLine = f.log.splitLines.filterIt(it.strip.len > 0 and not it.startsWith("(exit code"))
        let errLines = lastLine.filterIt("Error" in it or "error:" in it)
        let why = if errLines.len > 0: errLines[^1] elif lastLine.len > 0: lastLine[^1] else: f.error
        notes.add &"- **{m}, {o}** failed in {failed.len} of {sessions[(s, o, m)].len} runs, at cell {f.failedAt} ({f.error}): `{why.replace(\"`\", \"'\")[0 ..< min(why.len, 160)]}`\n"
    for msg in outputMismatches(s, o):
      notes.add &"- **output check, {o}**: {msg}\n"
  if notes.len > 0:
    nbText: "**Failures and output checks**\n\n" & notes
  else:
    nbText: "All sessions completed, and the outputs agree across modes."

nbText: "## Runs\n\n| run | machine | Nim | C compiler | cicak commit | arguments |\n|---|---|---|---|---|---|\n" &
  metas.mapIt(&"""| {it["run"].getStr} | {it["machine"]["cpu"].getStr}, {it["machine"]["cores"].getInt} cores, {it["machine"]["memory"].getStr} | {it["nim"].getStr} | {it["cc"].getStr} | {it["cicakCommit"].getStr} | `{it["args"].to(seq[string]).join(" ")}` |""").join("\n")
nbSave
