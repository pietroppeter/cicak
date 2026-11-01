## The session engine the benchmark drives: one module per cell, compiled with
## `nim c` or `nim ic`, and run either by re-running the whole program (rerun)
## or by hot code reloading into a long-running host (hcr). The same mechanism
## as cicak-app's engine, without its web server, locks and session limits, and
## with each compile step split into Nim, C compile and link time.
##
## Cell 0 is the session's start: compiling and running the program with no
## cells (rerun), or compiling and starting the host (hcr). It holds the
## one-off cost of compiling `system`, so cell 1 shows the cost of a cell.

import std/[os, osproc, streams, strutils, strtabs, monotimes, times, algorithm]

type
  Compiler* = enum ccC = "c", ccIc = "ic"
  Strategy* = enum stRerun = "rerun", stHcr = "hcr"
  Opt* = enum optDebug = "debug", optRelease = "release", optDanger = "danger"
  Mode* = object
    compiler*: Compiler
    strategy*: Strategy
  Step* = object
    name*: string     ## compile, run, start host, reload
    wallMs*: float
    nimMs*, ccMs*, linkMs*, runMs*: float  ## the phases; they add up to wallMs
    cFiles*: int      ## C files compiled in this step
    ok*: bool
    log*: string
  CellResult* = object
    index*: int
    ok*: bool
    steps*: seq[Step]
    output*: string   ## what the program printed in this step
    error*: string
  Config* = object
    nimExe*: string
    nimLib*: string
    ccwrap*: string   ## absolute path of ccwrap.sh
    extraFlags*: string  ## e.g. --path: for a scenario's dependencies
    compileTimeoutS*, runTimeoutS*: int
  Session* = ref object
    cfg: Config
    dir*: string
    mode*: Mode
    opt*: Opt
    cells: int
    host: Process

const
  Marker = "\x1fcicak:"
  HostSource = """
import std/hotcodereloading
import cells

setStdIoUnbuffered()
stdout.write "$1ready\n"
stdout.flushFile
var line: string
while stdin.readLine(line):
  if line == "reload":
    performCodeReload()
    stdout.write "$1done\n"
    stdout.flushFile
""" % Marker
  MaxLog = 20_000

proc `$`*(m: Mode): string = $m.compiler & "+" & $m.strategy

proc parseMode*(s: string): Mode =
  let parts = s.split('+')
  if parts.len != 2: raise newException(ValueError, "mode is <c|ic>+<rerun|hcr>: " & s)
  Mode(compiler: parseEnum[Compiler](parts[0]), strategy: parseEnum[Strategy](parts[1]))

proc optFlags*(o: Opt): string =
  case o
  of optDebug: ""
  of optRelease: "-d:release"
  of optDanger: "-d:danger"

proc elapsedMs(t0: MonoTime): float = (getMonoTime() - t0).inMicroseconds.float / 1000

proc clip(s: string): string =
  ## Keeps the end, where compilers put the error.
  if s.len <= MaxLog: s else: "(" & $(s.len - MaxLog) & " bytes before) …\n" & s[^MaxLog .. ^1]

proc unionMs(intervals: seq[(int64, int64)]): float =
  ## Total length of a set of possibly overlapping intervals (C compiles run in parallel).
  if intervals.len == 0: return 0
  var iv = intervals.sorted
  var (s, e) = iv[0]
  var total = 0'i64
  for (a, b) in iv[1 .. ^1]:
    if a > e:
      total += e - s
      (s, e) = (a, b)
    else:
      e = max(e, b)
  total += e - s
  total.float / 1e6

proc ccEnv(logFile: string, extra: StringTableRef = nil): StringTableRef =
  result = newStringTable(modeCaseSensitive)
  for k, v in envPairs(): result[k] = v
  result["CICAK_CCLOG"] = logFile
  if extra != nil:
    for k, v in extra: result[k] = v

proc shell(cmd, dir: string, timeoutS: int, env: StringTableRef): (string, int, float) =
  let t0 = getMonoTime()
  let full = (if findExe("timeout").len > 0: "timeout " & $timeoutS & " " else: "") & cmd
  let p = startProcess("/bin/sh", workingDir = dir, args = ["-c", full], env = env,
                       options = {poStdErrToStdOut})
  let output = p.outputStream.readAll
  let code = p.waitForExit
  p.close
  (output, code, elapsedMs(t0))

proc compileStep(s: Session, name, cmd: string): Step =
  ## Runs a Nim compile and splits its time using the log ccwrap.sh writes.
  let logFile = s.dir / "cc.log"
  removeFile logFile
  let (output, code, ms) = shell(cmd, s.dir, s.cfg.compileTimeoutS, ccEnv(logFile))
  var cc, link, all: seq[(int64, int64)]
  if fileExists(logFile):
    for line in lines(logFile):
      let f = line.splitWhitespace
      if f.len != 3: continue
      let iv = (parseBiggestInt(f[1]).int64, parseBiggestInt(f[2]).int64)
      all.add iv
      if f[0] == "cc": cc.add iv else: link.add iv
  result = Step(name: name, wallMs: ms, ok: code == 0, cFiles: cc.len,
                ccMs: unionMs(cc), linkMs: unionMs(link))
  # when C compiles and links overlap, the overlap is counted once, as C compile
  result.linkMs = max(0.0, unionMs(all) - result.ccMs)
  result.nimMs = max(0.0, ms - result.ccMs - result.linkMs)
  result.log = clip(output.replace(s.dir & "/", "").strip)
  if code == 124: result.log.add "\n(timed out after " & $s.cfg.compileTimeoutS & " s)"
  elif code != 0: result.log.add "\n(exit code " & $code & ")"

proc baseFlags(cfg: Config, opt: Opt): string =
  "--hints:off --warnings:off --gcc.exe:" & cfg.ccwrap & " --gcc.linkerexe:" & cfg.ccwrap &
    " " & optFlags(opt) & " " & cfg.extraFlags

proc rtlDir(cfg: Config, root: string, opt: Opt): string = root / "rtl-" & $opt

proc buildRtl*(cfg: Config, root: string, opt: Opt): (bool, float, string) =
  ## Builds libnimrtl and libnimhcr for hot code reloading, once per build mode.
  ## Their cost is reported in the run's metadata, not in any session.
  let dir = rtlDir(cfg, root, opt)
  let (rtl, hcr) = (DynlibFormat % "nimrtl", DynlibFormat % "nimhcr")
  if fileExists(dir / rtl) and fileExists(dir / hcr): return (true, 0.0, "")
  createDir dir
  var total = 0.0
  for (lib, def) in [("nimrtl", "createNimRtl"), ("nimhcr", "createNimHcr")]:
    let cmd = cfg.nimExe & " c " & baseFlags(cfg, opt) & " --app:lib -d:" & def &
              " --nimcache:nimcache_" & lib & " --out:" & (DynlibFormat % lib) & " " &
              quoteShell(cfg.nimLib / lib & ".nim")
    let (output, code, ms) = shell(cmd, dir, cfg.compileTimeoutS, ccEnv(""))
    total += ms
    if code != 0: return (false, total, output)
  (true, total, "")

proc compileCmd(s: Session, main, output: string): string =
  result = s.cfg.nimExe & " " & $s.mode.compiler & " " & baseFlags(s.cfg, s.opt) &
           " --nimcache:nimcache"
  if s.mode.strategy == stHcr: result.add " --hotcodereloading:on"
  result.add " --out:" & output & " " & main

proc writeCells(s: Session) =
  var all = ""
  for i in 1 .. s.cells: all.add "import cell_" & $i & "\n"
  writeFile(s.dir / "cells.nim", all)

proc readUntilMarker(s: Session, what: string, output: var string): bool =
  var line: string
  while s.host.outputStream.readLine(line):
    if line.startsWith(Marker):
      if line == Marker & what: return true
    else:
      output.add line & "\n"
  false

proc stop*(s: Session) =
  if s.host != nil:
    try:
      s.host.terminate
      discard s.host.waitForExit(2000)
      if s.host.running: s.host.kill
      s.host.close
    except CatchableError: discard
    s.host = nil

proc runStep(s: Session, name, cmd: string): (Step, string) =
  let (output, code, ms) = shell(cmd, s.dir, s.cfg.runTimeoutS, nil)
  var st = Step(name: name, wallMs: ms, runMs: ms, ok: code == 0)
  if code == 124: st.log = "(timed out after " & $s.cfg.runTimeoutS & " s)"
  elif code != 0: st.log = clip(output.strip) & "\n(exit code " & $code & ")"
  (st, output)

proc build(s: Session, res: var CellResult) =
  ## Compiles and runs (rerun) or compiles and reloads (hcr) the current cells.
  case s.mode.strategy
  of stRerun:
    let c = s.compileStep("compile", s.compileCmd("prog.nim", "prog"))
    res.steps.add c
    if not c.ok:
      res.error = "compile failed"; return
    let (r, output) = s.runStep("run", "./prog")
    res.steps.add r
    res.output = output
    if not r.ok:
      res.error = "run failed"; return
  of stHcr:
    let first = s.host == nil
    let c = s.compileStep("compile", s.compileCmd("host.nim", if first: "host" else: "host.next"))
    res.steps.add c
    if not c.ok:
      res.error = "compile failed"; return
    let t1 = getMonoTime()
    var output = ""
    var ok = false
    if first:
      let env = newStringTable(modeCaseSensitive)
      for k, v in envPairs(): env[k] = v
      let v = when defined(macosx): "DYLD_LIBRARY_PATH" else: "LD_LIBRARY_PATH"
      env[v] = s.cfg.rtlDir(s.dir.parentDir, s.opt)
      s.host = startProcess(s.dir / "host", workingDir = s.dir, env = env,
                            options = {poStdErrToStdOut})
      ok = s.readUntilMarker("ready", output)
    else:
      try:
        s.host.inputStream.write "reload\n"
        s.host.inputStream.flush
        ok = s.readUntilMarker("done", output)
      except CatchableError as e:
        output.add e.msg
    let ms = elapsedMs(t1)
    res.steps.add Step(name: (if first: "start host" else: "reload"), wallMs: ms, runMs: ms,
                       ok: ok, log: (if ok: "" else: clip(output.strip)))
    res.output = output
    if not ok:
      s.stop
      res.error = "host exited"

proc finish(res: var CellResult, t0: MonoTime) =
  res.ok = res.error.len == 0 and res.steps.len > 0
  for st in res.steps:
    if not st.ok: res.ok = false

proc newSession*(cfg: Config, root, name: string, mode: Mode, opt: Opt): Session =
  ## A fresh session directory under `root`, with an empty nimcache.
  result = Session(cfg: cfg, dir: root / name, mode: mode, opt: opt)
  removeDir result.dir
  createDir result.dir
  writeFile(result.dir / "host.nim", HostSource)
  writeFile(result.dir / "prog.nim", "import cells\n")
  writeFile(result.dir / "cells.nim", "")

proc start*(s: Session): CellResult =
  ## Cell 0: the program with no cells.
  let t0 = getMonoTime()
  result.index = 0
  s.build(result)
  result.finish(t0)

proc addCell*(s: Session, code: string): CellResult =
  let t0 = getMonoTime()
  inc s.cells
  let k = s.cells
  var imports = ""
  for i in 1 ..< k: imports.add "import cell_" & $i & "\n"
  writeFile(s.dir / "cell_" & $k & ".nim", imports & code & "\n")
  s.writeCells
  result.index = k
  s.build(result)
  result.finish(t0)

proc cleanup*(s: Session) =
  s.stop
  removeDir s.dir
