## The cicak benchmark: runs scenarios of cells in every mode and build mode,
## several times, and writes one JSON line per step. Design: bench/DESIGN.md.
##
##   nim r -d:release bench/bench.nim [options]
##
## Options (comma-separated lists):
##   --scenarios:s0,s1,s2,s3  (default all)
##   --modes:c+rerun,ic+rerun,c+hcr,ic+hcr  (default all four)
##   --opts:debug,release     (default; danger is also available)
##   --reps:5                 repetitions, interleaved
##   --cells:20               cells per scenario (s0 is generated, others are cut)
##   --s0cells:100            cells for s0 (default 100)
##   --label:cloud            names the machine in the run id
##   --out:bench/results      parent of the run directory
##   --work:/tmp/cicak-bench  where sessions are built
##   --keepGoing              after a failed cell, keep adding cells (default: stop)
##   --calibrationOnly        only the calibration session, twice (an environment's reference)
##
## Writes <out>/<run id>/{meta.json,steps.jsonl,cells.jsonl}. Not run on CI.

import std/[os, osproc, parseopt, strutils, sequtils, json, times, monotimes, tables, streams]
import engine, scenario

let benchDir = currentSourcePath().parentDir

proc cmdOut(cmd: string): string =
  try: execCmdEx(cmd).output.strip except CatchableError: ""

proc nimLibDir(nimExe: string): string =
  if existsEnv("NIM_LIB"): return getEnv("NIM_LIB")
  var exe = findExe(nimExe)
  try: exe = expandFilename(exe) except OSError: discard
  result = exe.parentDir.parentDir / "lib"

proc memTotal(): string =
  if fileExists("/proc/meminfo"):
    for line in lines("/proc/meminfo"):
      if line.startsWith("MemTotal:"):
        return $(parseInt(line.splitWhitespace[1]) div (1024 * 1024)) & " GB"
  cmdOut("sysctl -n hw.memsize")

proc machine(): JsonNode =
  var cpu = ""
  if fileExists("/proc/cpuinfo"):
    for line in lines("/proc/cpuinfo"):
      if line.startsWith("model name"):
        cpu = line.split(':', 1)[1].strip; break
  if cpu == "": cpu = cmdOut("sysctl -n machdep.cpu.brand_string")
  %*{"cpu": cpu, "cores": countProcessors(), "os": cmdOut("uname -srm"),
     "memory": memTotal(),
     "hostname": cmdOut("hostname")}

proc main() =
  var
    scenarios = @["s0", "s1", "s2", "s3"]
    modes = @["c+rerun", "ic+rerun", "c+hcr", "ic+hcr"]
    opts = @["debug", "release"]
    reps = 5
    cells = 20
    s0cells = 100
    label = "local"
    outDir = benchDir / "results"
    work = getTempDir() / "cicak-bench"
    keepGoing = false
    calibrationOnly = false
  for kind, key, val in getopt():
    if kind notin {cmdLongOption, cmdShortOption}: continue
    case key
    of "scenarios": scenarios = val.split(',')
    of "modes": modes = val.split(',')
    of "opts": opts = val.split(',')
    of "reps": reps = parseInt(val)
    of "cells": cells = parseInt(val)
    of "s0cells": s0cells = parseInt(val)
    of "label": label = val
    of "out": outDir = val
    of "work": work = val
    of "keepGoing": keepGoing = true
    of "calibrationOnly": calibrationOnly = true
    else: quit "unknown option --" & key

  let nimExe = getEnv("NIM", "nim")
  let cfg0 = Config(nimExe: nimExe, nimLib: nimLibDir(nimExe), ccwrap: benchDir / "ccwrap.sh",
                    compileTimeoutS: 900, runTimeoutS: 600)
  if calibrationOnly: scenarios = @[]
  var sc: Table[string, Scenario]
  for f in walkFiles(benchDir / "scenarios" / "*.nim"):
    let s = loadScenario(f)
    if s.id in scenarios:
      var s2 = s
      if s2.cells.len > cells: s2.cells.setLen(cells)
      sc[s.id] = s2
  if "s0" in scenarios: sc["s0"] = scenario0(s0cells)
  for id in scenarios:
    if id notin sc: quit "no scenario " & id
    for p in sc[id].paths:
      if not dirExists(benchDir / p): quit id & " needs " & p & ": run bench/deps.sh"

  let runId = now().utc.format("yyyy-MM-dd'T'HH-mm") & "-" & label
  let dir = outDir / runId
  createDir dir
  createDir work
  let started = now().utc
  var meta = %*{
    "run": runId, "label": label, "started": $started,
    "machine": machine(),
    "nim": cmdOut(nimExe & " -v").splitLines()[0],
    "cc": cmdOut(getEnv("CICAK_CC", "gcc") & " --version").splitLines()[0],
    "cicakCommit": cmdOut("git -C " & quoteShell(benchDir) & " rev-parse --short HEAD"),
    "args": commandLineParams(),
    "scenarios": newJObject(), "rtl": newJObject(),
    "calibration": {"scenario": "cal", "mode": "c+rerun", "opt": "debug", "cells": calibration().cells.len}}
  for id in scenarios:
    meta["scenarios"][id] = %*{"title": sc[id].title, "cells": sc[id].cells.len,
                               "cellTitles": sc[id].cells.mapIt(it[0])}

  # hot reload's runtime libraries: one-off, outside the sessions
  for o in opts:
    let (ok, ms, log) = buildRtl(cfg0, work, parseEnum[Opt](o))
    meta["rtl"][o] = %*{"ok": ok, "ms": ms, "log": log}

  let steps = newFileStream(dir / "steps.jsonl", fmWrite)
  let cellsOut = newFileStream(dir / "cells.jsonl", fmWrite)
  proc record(base: JsonNode, r: CellResult) =
    for i, st in r.steps:
      var row = base.copy
      row["cell"] = %r.index
      row["step"] = %st.name
      for k, v in %*{"wallMs": st.wallMs, "nimMs": st.nimMs, "ccMs": st.ccMs,
                     "linkMs": st.linkMs, "runMs": st.runMs, "cFiles": st.cFiles, "ok": st.ok}:
        row[k] = v
      steps.writeLine $row
    var c = base.copy
    c["cell"] = %r.index
    c["ok"] = %r.ok
    c["output"] = %r.output
    c["error"] = %r.error
    c["log"] = %(block:
      var l = ""
      for st in r.steps:
        if not st.ok: l.add st.log & "\n"
      l)
    cellsOut.writeLine $c
    steps.flush; cellsOut.flush

  # a throwaway session first: warms the OS file cache and the C compiler
  block:
    let s = newSession(cfg0, work, "warmup", parseMode("c+rerun"), optDebug)
    discard s.start
    for i in 1 .. 3: discard s.addCell("var w" & $i & "* = " & $i)
    s.cleanup

  proc runOne(id: string, scn: Scenario, mode: Mode, opt: Opt, rep: int, label: string) =
    var cfg = cfg0
    for p in scn.paths: cfg.extraFlags.add " --path:" & quoteShell(benchDir / p)
    let base = %*{"run": runId, "scenario": id, "mode": $mode, "compiler": $mode.compiler,
                  "strategy": $mode.strategy, "opt": $opt, "rep": rep}
    let t0 = getMonoTime()
    stdout.write label & " " & id & " " & $mode & " " & $opt & " rep " & $rep & ": "
    stdout.flushFile
    let s = newSession(cfg, work, "session", mode, opt)
    var r = s.start
    record(base, r)
    var done = 0
    if r.ok:
      for (title, code) in scn.cells:
        r = s.addCell(code)
        record(base, r)
        if r.ok: inc done
        elif not keepGoing: break
    s.cleanup
    echo done, "/", scn.cells.len, " cells in ",
         formatFloat((getMonoTime() - t0).inMilliseconds.float / 1000, ffDecimal, 1), " s",
         (if r.ok: "" else: " (failed: " & r.error & ")")

  # calibration at the start (rep 1) and at the end (rep 2) of the run
  let cal = calibration()
  runOne("cal", cal, parseMode("c+rerun"), optDebug, 1, "[calibration]")
  let total = reps * scenarios.len * opts.len * modes.len
  var n = 0
  for rep in 1 .. reps:
    for id in scenarios:
      for o in opts:
        for m in modes:
          inc n
          runOne(id, sc[id], parseMode(m), parseEnum[Opt](o), rep, "[" & $n & "/" & $total & "]")
  runOne("cal", cal, parseMode("c+rerun"), optDebug, 2, "[calibration]")
  steps.close
  cellsOut.close
  meta["finished"] = % $now().utc
  writeFile(dir / "meta.json", meta.pretty)
  echo "wrote ", dir

when isMainModule: main()
