## Cells as modules with hot code reloading: start a host with one cell,
## then add c2 and c3 to the running process.
## Run with `nim r experiments/hcr-cells/run.nim` (needs Nim >= 2.4).
import std/[exitprocs, os, osproc, times]

const
  flags = "--hints:off --warnings:off"
  hostTimeout = initDuration(seconds = 30) # the host should exit after its two reloads

proc compile(args: string) =
  ## Runs `nim c` and stops at the first failure.
  let cmd = "nim c " & flags & " " & args
  if execShellCmd(cmd) != 0:
    quit "failed: " & cmd

proc setCells(cells: string) =
  ## `cells.nim` imports every cell so far; a REPL would rewrite it after each input.
  writeFile("cells.nim", "import " & cells & "\n")

setCurrentDir(currentSourcePath().parentDir)
addExitProc(proc () = setCells "c1") # leave cells.nim as committed, also on failure
let nimLib = findExe("nim").parentDir.parentDir / "lib"

# the two runtime libraries HCR needs
compile "--app:lib -d:createNimRtl --out:libnimrtl.so " & nimLib / "nimrtl.nim"
compile "--app:lib -d:createNimHcr --out:libnimhcr.so " & nimLib / "nimhcr.nim"

# the host starts with only c1, in the background
setCells "c1"
removeFile "go"
compile "--hotCodeReloading:on --out:host main.nim"
putEnv("LD_LIBRARY_PATH", getCurrentDir())
let host = startProcess(getCurrentDir() / "host", options = {poParentStreams})
addExitProc(proc () = (if host.running: host.kill))

sleep 2000
for cells in ["c1, c2", "c1, c2, c3"]:
  setCells cells
  # the running host's executable can't be overwritten; the cell libraries are what matter
  compile "--hotCodeReloading:on --out:host.next main.nim"
  writeFile("go", "") # the host reloads when it sees this file
  sleep 2000

let deadline = getTime() + hostTimeout
while host.running and getTime() < deadline:
  sleep 100
if host.running:
  quit "the host did not exit within " & $hostTimeout
if host.peekExitCode != 0:
  quit "the host failed with exit code " & $host.peekExitCode
