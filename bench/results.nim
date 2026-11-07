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
  envSessions: OrderedTable[string, Table[Key, seq[Session]]]  ## environment (run label) -> sessions
  sessions: Table[Key, seq[Session]]      ## the environment being rendered; one per repetition
  envs: seq[string]                       ## in the order of their first run
  titles: Table[string, string]
  cellTitles: Table[string, seq[string]]

for d in runDirs:
  let meta = parseFile(d / "meta.json")
  metas.add meta
  let env = meta["label"].getStr
  if env notin envs: envs.add env
  if env notin envSessions: envSessions[env] = initTable[Key, seq[Session]]()
  for id, s in meta["scenarios"]:
    titles[id] = s["title"].getStr
    cellTitles[id] = s["cellTitles"].to(seq[string])
  # a run killed before its end: only its complete repetitions (and the first calibration)
  let repsDone = (if meta.hasKey("finished") or not meta.hasKey("repsDone"): int.high
                  else: meta["repsDone"].getInt)
  proc partial(r: JsonNode): bool =
    r["rep"].getInt > repsDone and not (r["scenario"].getStr == "cal" and r["rep"].getInt == 1)
  var bySession: OrderedTable[(Key, int), Session]
  for line in lines(d / "steps.jsonl"):
    let r = parseJson(line)
    if partial(r): continue
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
    if partial(r): continue
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
    envSessions[env].mgetOrPut(sk[0], @[]).add s

proc median(xs: seq[float]): float =
  if xs.len == 0: return NaN
  let s = xs.sorted
  if s.len mod 2 == 1: s[s.len div 2] else: (s[s.len div 2 - 1] + s[s.len div 2]) / 2

proc total(c: CellTime): float = c[phNim] + c[phCc] + c[phLink] + c[phRun]

proc complete(ss: seq[Session]): seq[Session] = ss.filterIt(not it.failed)

proc last10(s: Session): float =
  ## Mean time per cell (ms) over cells 11 to 20, the last 10 cells of a 20-cell
  ## scenario: how snappy the REPL feels once a session is under way. Fixed cells
  ## rather than a session's own last 10, so s0 compares across runs of any length.
  let n = min(20, s.cells.len - 1)
  let first = max(1, n - 9)
  s.cells[first .. n].mapIt(it.total).sum / float(n - first + 1)

proc sec(ms: float): string =
  if ms.isNaN: "–" else: formatFloat(ms / 1000, ffDecimal, (if ms < 10_000: 2 else: 1))

proc scenariosIn(): seq[string] =
  for k in sessions.keys:
    if k.scenario notin result and k.scenario != "cal": result.add k.scenario
  result.sort

# ---- environments ----------------------------------------------------------

proc reference(env: string): array[Phase, float] =
  ## The environment's reference time per phase (ms), from its calibration
  ## sessions: Nim over cells 1-10, C compile and link over cells 0-10, and run
  ## for the fixed computation in cell 11. NaN without calibration.
  for ph in Phase: result[ph] = NaN
  let cal = envSessions[env].getOrDefault(("cal", "debug", "c+rerun")).complete.filterIt(it.cells.len >= 12)
  if cal.len == 0: return
  result[phNim] = median(cal.mapIt(it.cells[1 .. 10].mapIt(it[phNim]).sum))
  result[phCc] = median(cal.mapIt(it.cells[0 .. 10].mapIt(it[phCc]).sum))
  result[phLink] = median(cal.mapIt(it.cells[0 .. 10].mapIt(it[phLink]).sum))
  result[phRun] = median(cal.mapIt(it.cells[11][phRun]))

proc calibrated(env: string): bool = not reference(env)[phNim].isNaN

proc drift(env: string): string =
  ## Calibration at the end of a run against its start, whole session.
  let cal = envSessions[env].getOrDefault(("cal", "debug", "c+rerun")).complete
  if cal.len < 2: return "–"
  let (a, b) = (cal[0].cells.mapIt(it.total).sum, cal[^1].cells.mapIt(it.total).sum)
  (if b >= a: "+" else: "") & formatFloat((b / a - 1) * 100, ffDecimal, 0) & "%"

proc optsIn(scenario: string): seq[string] =
  for o in optsOrder:
    for m in modesOrder:
      if (scenario, o, m) in sessions and o notin result: result.add o

proc modesIn(scenario, opt: string): seq[string] =
  modesOrder.filterIt((scenario, opt, it) in sessions)

# ---- charts --------------------------------------------------------------

var chartCount = 0
proc chart(traces: seq[JsonNode], layout: JsonNode, height = 380, legendY = -0.18): string =
  ## A plotly chart as HTML; plotly.js is vendored in docs/assets (loaded once, in the head).
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

proc tickStep(scenario: string): int =
  if cellTitles.getOrDefault(scenario).len > 40: 10 else: 5

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
                   "xaxis": {"title": {"text": "cell (0 = session start)"}, "dtick": tickStep(scenario)},
                   "yaxis": {"title": {"text": "s"}, "rangemode": "tozero"}}, 440, -0.3)

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
    lay["xaxis" & ax] = %*{"dtick": tickStep(scenario), "matches": "x"}
    lay["yaxis" & ax] = %*{"matches": "y", "rangemode": "tozero"}
    annotations.add %*{"text": modeNames[m], "xref": "x" & ax & " domain", "yref": "y" & ax & " domain",
                       "x": 0, "y": 1.12, "showarrow": false, "xanchor": "left",
                       "font": {"size": 11, "color": "#7c8c82"}}
  lay["annotations"] = %annotations
  chart(traces, lay, 140 + 150 * ms.len)

proc totalsChart(): string =
  ## Median whole-session time, stacked by phase: one panel per scenario (scenarios
  ## never share an axis), one bar per build mode and mode.
  let scs = scenariosIn()
  var traces: seq[JsonNode]
  var lay = %*{"barmode": "stack", "bargap": 0.25,
               "grid": {"rows": scs.len, "columns": 1, "pattern": "independent", "ygap": 0.45}}
  var annotations: seq[JsonNode]
  for i, sc in scs:
    let ax = if i == 0: "" else: $(i + 1)
    var cats: seq[(string, string, string)]   # (label, opt, mode)
    for o in optsIn(sc):
      for m in modesIn(sc, o):
        if sessions[(sc, o, m)].complete.len > 0: cats.add (o & " · " & m, o, m)
    for ph in Phase:
      var ys: seq[float]
      for (label, o, m) in cats:
        ys.add median(sessions[(sc, o, m)].complete.mapIt(it.cells.mapIt(it[ph]).sum / 1000))
      var t = trace(Trace[float](`type`: PlotType.Bar, text: cats.mapIt(it[0]), ys: ys, name: $ph))
      t["x"] = %cats.mapIt(it[0])
      t.delete "text"
      t["xaxis"] = %("x" & ax)
      t["yaxis"] = %("y" & ax)
      t["marker"] = %*{"color": palette[ph.ord], "line": {"width": 0}}
      t["legendgroup"] = % $ph
      t["showlegend"] = %(i == 0)
      t["hovertemplate"] = %(&"{sc} · %{{x}}<br>{ph}: %{{y:.1f}} s<extra></extra>")
      traces.add t
    lay["xaxis" & ax] = %*{"tickangle": -35, "tickfont": {"size": 10}}
    lay["yaxis" & ax] = %*{"rangemode": "tozero"}
    annotations.add %*{"text": "<b>" & sc & "</b> " & titles.getOrDefault(sc, sc),
                       "xref": "x" & ax & " domain", "yref": "y" & ax & " domain",
                       "x": 0, "y": 1.18, "showarrow": false, "xanchor": "left",
                       "font": {"size": 12, "color": "#5a6f62"}}
  lay["annotations"] = %annotations
  if traces.len == 0: return ""
  chart(traces, lay, 120 + 300 * scs.len, -0.6 / scs.len.float)

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
nb.doc.context["home_href"] = %"../"  # the dev log index, one level up on the site
nb.doc.context["stylesheet"] = %(nb.doc.context["stylesheet"].getStr & "\n<script src=\"" & nb.assetsHref & "plotly/plotly-2.35.2.min.js\"></script>\n<style>.bench-chart{width:100%;margin:1rem 0 2rem}</style>")

nbText: """
**This page is a living document**: it is rendered from every run committed in
`bench/results`, so it changes with each new run. What the results mean is in dated
dev log posts, which keep a snapshot of the charts they discuss:
[What the first benchmark runs say](../blog/2026-11-06-bench-results.html)
(6 November 2026, runs of 1 November).
"""

# the setup section describes every environment's runs together
for env, t in envSessions:
  for k, v in t: sessions.mgetOrPut(k, @[]).add v

proc scenarioSource(id: string): string =
  for f in walkFiles(benchDir / "scenarios" / (id & "_*.nim")):
    return "[scenarios/" & f.extractFilename & "](https://github.com/pietroppeter/cicak/blob/main/bench/scenarios/" & f.extractFilename & ")"
  "generated by [bench.nim](https://github.com/pietroppeter/cicak/blob/main/bench/bench.nim)"

proc argValue(meta: JsonNode, key, default: string): string =
  for a in meta["args"]:
    let s = a.getStr
    if s.startsWith("--" & key & ":"): return s.split(':', 1)[1]
  default

var setup = """
## How the benchmark is set up

Why it is set up this way is in the [design doc](design.html); this section says what was run.
Every cell of every scenario is on the [scenarios page](scenarios.html).

**A session** starts empty and adds the cells of one scenario one at a time, as a REPL user would.
Each cell is a Nim module that imports every earlier cell. **Cell 0** is the session start: the
program with no cells is compiled and run (re-run) or the host is compiled and started (hot reload),
which includes compiling `system`. Every session starts from an empty build cache. A cell that fails
ends its session.

**Four modes**, each the combination of a compiler and a way of running cells:

| mode | compiler | how a new cell runs |
|---|---|---|
| `c+rerun` | `nim c` | the whole program is recompiled and run again: every cell's code runs again |
| `ic+rerun` | `nim ic` (incremental) | the same, compiled incrementally |
| `c+hcr` | `nim c --hotcodereloading:on` | a host process stays alive and hot reloads the new cell: only its code runs |
| `ic+hcr` | `nim ic --hotcodereloading:on` | the same, compiled incrementally (fails on Nim 2.4) |

**Build modes**: debug (no flag), release (`-d:release`), danger (`-d:danger`).

**Phases** of each cell, stacked in the charts: *Nim* (the Nim compiler itself), *C compile*
(gcc on the generated C files), *link*, and *run or reload* (running the program, starting the
host or reloading the cell).

**Scenarios** (a scenario is never mixed with another in a chart or table):

| id | scenario | cells | build modes run | source |
|---|---|---|---|---|
"""
for sc in scenariosIn():
  setup.add &"| [{sc}](scenarios.html#{sc}) | {titles.getOrDefault(sc, sc)} | {cellTitles.getOrDefault(sc).len} | {optsIn(sc).join(\", \")} | {scenarioSource(sc)} |\n"
setup.add """

**Runs** (each repetition runs every scenario, build mode and mode of its run, interleaved):

| run | environment | scenarios | build modes | modes | repetitions | machine |
|---|---|---|---|---|---|---|
"""
for m in metas:
  if m["args"].to(seq[string]).anyIt(it == "--calibrationOnly"):
    setup.add &"""| {m["run"].getStr} | {m["label"].getStr} | calibration only | – | – | – | {m["machine"]["cpu"].getStr}, {m["machine"]["cores"].getInt} cores, {m["machine"]["memory"].getStr} |""" & "\n"
    continue
  setup.add &"""| {m["run"].getStr} | {m["label"].getStr} | {toSeq(m["scenarios"].keys).join(", ")} | {argValue(m, "opts", "debug,release").replace(",", ", ")} | {argValue(m, "modes", "all four").replace(",", ", ")} | {argValue(m, "reps", "5")} | {m["machine"]["cpu"].getStr}, {m["machine"]["cores"].getInt} cores, {m["machine"]["memory"].getStr} |""" & "\n"
setup.add """
Versions: """ & metas.mapIt(it["nim"].getStr & ", " & it["cc"].getStr).deduplicate.join("; ") & """.

**Environments** are the machines the runs come from (a run's label). Each run starts and ends
with a **calibration session**, always the same: `c+rerun`, debug, 10 cells of independent integer variables and a
cell with a fixed computation. Its median, phase by phase, is the environment's **reference**.
Times from different environments are compared only after dividing each phase by the
environment's reference for that phase. *Drift* is the calibration at the end of a run against
the one at its start.

| environment | machine | reference Nim (s) | C compile (s) | link (s) | run (s) | drift |
|---|---|---|---|---|---|---|
"""
for env in envs:
  let m = metas.filterIt(it["label"].getStr == env)[^1]
  let r = reference(env)
  setup.add &"""| {env} | {m["machine"]["cpu"].getStr}, {m["machine"]["cores"].getInt} cores, {m["machine"]["memory"].getStr} | {sec(r[phNim])} | {sec(r[phCc])} | {sec(r[phLink])} | {sec(r[phRun])} | {drift(env)} |""" & "\n"
setup.add """
**Reading the numbers**: times are medians over the repetitions; ranges and bands show the
minimum and maximum. Totals include cell 0. Within an environment, times are seconds; across
environments, only normalised times and ratios are shown.
"""
nbText: setup

proc snappyChart(): string =
  ## Mean time per cell over the last 10 cells, per scenario panel, one bar per
  ## environment (median over repetitions, whiskers min to max), and a 1 s line.
  ## Raw seconds on purpose: this is what a user of that machine waits.
  var scs: seq[string]
  for env in envs:
    for k in envSessions[env].keys:
      if k.scenario != "cal" and k.scenario notin scs: scs.add k.scenario
  scs.sort
  if scs.len == 0: return ""
  var traces: seq[JsonNode]
  var lay = %*{"barmode": "group", "bargap": 0.25,
               "grid": {"rows": scs.len, "columns": 1, "pattern": "independent", "ygap": 0.45}}
  var annotations, shapes: seq[JsonNode]
  for i, sc in scs:
    let ax = if i == 0: "" else: $(i + 1)
    var cats: seq[(string, string)]
    for o in optsOrder:
      for m in modesOrder:
        for env in envs:
          if envSessions[env].getOrDefault((sc, o, m)).complete.len > 0 and (o, m) notin cats: cats.add (o, m)
    for ei, env in envs:
      var ys, lo, hi: seq[float]
      for (o, m) in cats:
        let v = envSessions[env].getOrDefault((sc, o, m)).complete.mapIt(it.last10 / 1000)
        if v.len == 0: ys.add NaN; lo.add 0; hi.add 0
        else:
          let med = median(v)
          ys.add med; lo.add med - v.min; hi.add v.max - med
      let labels = cats.mapIt(it[0] & " · " & it[1])
      var tr = trace(Trace[float](`type`: PlotType.Bar, text: labels, ys: ys, name: env))
      tr["x"] = %labels
      tr.delete "text"
      tr["error_y"] = %*{"type": "data", "symmetric": false, "array": hi, "arrayminus": lo,
                         "color": "#7c8c82", "thickness": 1, "width": 3}
      tr["xaxis"] = %("x" & ax)
      tr["yaxis"] = %("y" & ax)
      tr["marker"] = %*{"color": palette[ei mod palette.len], "line": {"width": 0}}
      tr["legendgroup"] = %env
      tr["showlegend"] = %(i == 0)
      tr["hovertemplate"] = %(&"{sc} · %{{x}}<br>{env}: %{{y:.2f}} s per cell<extra></extra>")
      traces.add tr
    lay["xaxis" & ax] = %*{"tickangle": -35, "tickfont": {"size": 10}}
    lay["yaxis" & ax] = %*{"rangemode": "tozero", "title": {"text": "s per cell"}}
    shapes.add %*{"type": "line", "xref": "x" & ax & " domain", "yref": "y" & ax, "x0": 0, "x1": 1,
                  "y0": 1, "y1": 1, "line": {"color": "#c0392b", "width": 1, "dash": "dot"}}
    annotations.add %*{"text": "<b>" & sc & "</b> " & titles.getOrDefault(sc, sc),
                       "xref": "x" & ax & " domain", "yref": "y" & ax & " domain",
                       "x": 0, "y": 1.18, "showarrow": false, "xanchor": "left",
                       "font": {"size": 12, "color": "#5a6f62"}}
  lay["annotations"] = %annotations
  lay["shapes"] = %shapes
  chart(traces, lay, 120 + 300 * scs.len, -0.6 / scs.len.float)

block:
  let html = snappyChart()
  if html.len > 0:
    nbText: "## How snappy, once a session is under way\n\nMean time per cell over **cells 11 to 20** of each session (the last 10 cells of a 20-cell scenario; for s0 too, whatever its length), in seconds, per scenario, build mode and environment (median over repetitions; whiskers from the fastest to the slowest repetition). Below the dotted 1 s line a REPL feels snappy; the lower, the snappier. These are raw seconds on purpose, also across environments: they are what someone using that machine waits."
    nbRawHtml: html

proc summaryTable(s: string): string =
  result = "| build | mode | cells ok | cell 0 (s) | per cell (s) | cells 11–20 (s per cell) | total (s), min–max |\n|---|---|---|---|---|---|---|\n"
  for o in optsIn(s):
    for m in modesIn(s, o):
      let all = sessions[(s, o, m)]
      let ss = all.complete
      let n = cellTitles.getOrDefault(s).len
      let okCells = all.mapIt(it.okCells).min
      if ss.len == 0:
        result.add &"| {o} | {m} | {okCells}/{n} | – | – | – | fails |\n"
        continue
      let c0 = median(ss.mapIt(it.cells[0].total))
      let perCell = median(ss.mapIt(it.cells[1 .. ^1].mapIt(it.total)).concat)
      let totals = ss.mapIt(it.cells.mapIt(it.total).sum)
      result.add &"| {o} | {m} | {okCells}/{n} | {sec(c0)} | {sec(perCell)} | {sec(median(ss.mapIt(it.last10)))} | {sec(median(totals))}, {sec(totals.min)}–{sec(totals.max)} |\n"

for env in envs:
  sessions = envSessions[env]
  let envSuffix = if envs.len > 1: " · " & env else: ""
  if envs.len > 1:
    nbText: &"# Environment: {env}\n\nRaw times, in seconds, on this environment only."
  block:
    let html = totalsChart()
    if html.len > 0:
      nbText: &"## Whole session, per scenario{envSuffix}\n\nMedian time of a whole session (s), stacked by phase. Each panel is one scenario, with its own scale."
      nbRawHtml: html

  for s in scenariosIn():
    nbText: &"## {s}: {titles.getOrDefault(s, s)}{envSuffix}\n\n" & summaryTable(s)
    block:
      var cells = "<details><summary>The " & $cellTitles.getOrDefault(s).len & " cells</summary><ol>"
      for t in cellTitles.getOrDefault(s): cells.add "<li>" & t.multiReplace(("&", "&amp;"), ("<", "&lt;")) & "</li>"
      nbRawHtml: cells & "</ol></details>"
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


# ---- across environments ----------------------------------------------------

proc wholeSession(env: string, k: Key): array[Phase, float] =
  ## Median whole-session time per phase (ms) in an environment; NaN if none completed.
  let ss = envSessions[env].getOrDefault(k).complete
  for ph in Phase:
    result[ph] = if ss.len == 0: NaN else: median(ss.mapIt(it.cells.mapIt(it[ph]).sum))

proc allScenarios(): seq[string] =
  for env in envs:
    for k in envSessions[env].keys:
      if k.scenario != "cal" and k.scenario notin result: result.add k.scenario
  result.sort

proc allCats(sc: string): seq[(string, string)] =
  for o in optsOrder:
    for m in modesOrder:
      for env in envs:
        if (sc, o, m) in envSessions[env] and envSessions[env][(sc, o, m)].complete.len > 0:
          if (o, m) notin result: result.add (o, m)

proc ratioTables(): string =
  ## Whole-session time against c+rerun in the same build mode: needs no reference.
  for sc in allScenarios():
    result.add &"**{sc}** {titles.getOrDefault(sc, sc)}\n\n| build · mode | " & envs.join(" | ") & " |\n|---|" & "---|".repeat(envs.len) & "\n"
    for (o, m) in allCats(sc):
      result.add &"| {o} · {m} |"
      for env in envs:
        let a = wholeSession(env, (sc, o, m)).sum
        let b = wholeSession(env, (sc, o, "c+rerun")).sum
        result.add " " & (if a.isNaN or b.isNaN: "–" else: formatFloat(a / b, ffDecimal, 2) & "×") & " |"
      result.add "\n"
    result.add "\n"

proc normalisedChart(): string =
  ## Whole-session time per environment, each phase divided by the environment's
  ## reference for it and expressed in seconds of the first environment's
  ## reference. One panel per scenario, one bar per environment.
  let cal = envs.filterIt(calibrated(it))
  if cal.len < 2: return ""
  let base = reference(cal[0])
  let scs = allScenarios()
  var traces: seq[JsonNode]
  var lay = %*{"barmode": "group", "bargap": 0.25,
               "grid": {"rows": scs.len, "columns": 1, "pattern": "independent", "ygap": 0.45}}
  var annotations: seq[JsonNode]
  for i, sc in scs:
    let ax = if i == 0: "" else: $(i + 1)
    let cats = allCats(sc)
    for ei, env in cal:
      let r = reference(env)
      var ys: seq[float]
      for (o, m) in cats:
        let w = wholeSession(env, (sc, o, m))
        var t = 0.0
        for ph in Phase: t += w[ph] / r[ph] * base[ph]
        ys.add t / 1000
      var tr = trace(Trace[float](`type`: PlotType.Bar, text: cats.mapIt(it[0] & " · " & it[1]), ys: ys, name: env))
      tr["x"] = %cats.mapIt(it[0] & " · " & it[1])
      tr.delete "text"
      tr["xaxis"] = %("x" & ax)
      tr["yaxis"] = %("y" & ax)
      tr["marker"] = %*{"color": palette[ei mod palette.len], "line": {"width": 0}}
      tr["legendgroup"] = %env
      tr["showlegend"] = %(i == 0)
      tr["hovertemplate"] = %(&"{sc} · %{{x}}<br>{env}: %{{y:.1f}} (normalised s)<extra></extra>")
      traces.add tr
    lay["xaxis" & ax] = %*{"tickangle": -35, "tickfont": {"size": 10}}
    lay["yaxis" & ax] = %*{"rangemode": "tozero"}
    annotations.add %*{"text": "<b>" & sc & "</b> " & titles.getOrDefault(sc, sc),
                       "xref": "x" & ax & " domain", "yref": "y" & ax & " domain",
                       "x": 0, "y": 1.18, "showarrow": false, "xanchor": "left",
                       "font": {"size": 12, "color": "#5a6f62"}}
  lay["annotations"] = %annotations
  chart(traces, lay, 120 + 300 * scs.len, -0.6 / scs.len.float)

block:
  var text = "## Comparing environments\n\n"
  let cal = envs.filterIt(calibrated(it))
  if cal.len >= 2:
    text.add &"Whole-session time with every phase normalised by its environment's reference, shown in seconds of the **{cal[0]}** reference (so {cal[0]}'s bars are its raw medians). A bar higher than {cal[0]}'s means that environment is slower at this than its calibration predicts.\n"
  else:
    text.add "Normalised comparisons appear here once two environments have calibrated runs" & (if cal.len == 1: &" (so far only **{cal[0]}**)." else: ".") & "\n"
  text.add "\n**Time against `c+rerun`** in the same build mode and environment (whole session, medians). Ratios need no reference, so they compare environments directly.\n\n" & ratioTables()
  nbText: text
  let html = normalisedChart()
  if html.len > 0: nbRawHtml: html

nbText: "## Run details\n\n| run | environment | machine | Nim | C compiler | cicak commit | arguments |\n|---|---|---|---|---|---|---|\n" &
  metas.mapIt(&"""| {it["run"].getStr} | {it["label"].getStr} | {it["machine"]["cpu"].getStr}, {it["machine"]["cores"].getInt} cores, {it["machine"]["memory"].getStr} | {it["nim"].getStr} | {it["cc"].getStr} | {it["cicakCommit"].getStr} | `{it["args"].to(seq[string]).join(" ")}` |""").join("\n")
nbSave
