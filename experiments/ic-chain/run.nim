## Time `nim ic` on a chain of 20 cell modules, then on adding a 21st cell.
## Run with `nim r experiments/ic-chain/run.nim`
## (needs Nim >= 2.4 built with nifler and nifmake).
import std/[os, osproc, monotimes, times, strformat, tempfiles]

proc run(cmd: string) =
  ## Runs a command, shows its output and stops at the first failure.
  let (output, exitCode) = execCmdEx(cmd)
  if exitCode != 0:
    quit output & "\nfailed: " & cmd
  stdout.write output

proc timed(cmd: string) =
  ## Runs a command quietly and prints how long it took.
  let start = getMonoTime()
  let (output, exitCode) = execCmdEx(cmd)
  if exitCode != 0:
    quit output & "\nfailed: " & cmd
  let seconds = (getMonoTime() - start).inMilliseconds.float / 1000
  echo &"{cmd} took {seconds:.2f} s"

# a fresh directory, so the IC cache starts empty
let dir = createTempDir("ic-chain-", "")
setCurrentDir dir

# c1 defines x; each next cell imports and re-exports the previous one
writeFile("c1.nim", "import std/[strutils, tables]\nvar x* = 1\n")
for i in 2..20:
  let prev = "c" & $(i - 1)
  writeFile(&"c{i}.nim", &"import {prev}\nexport {prev}\nvar x{i}* = x + {i}\n")
writeFile("main.nim", "import c20\necho x20\n")
timed "nim ic main.nim"
run "./main"

# add a 21st cell
writeFile("c21.nim", "import c20\nexport c20\nvar x21* = x20 * 2\n")
writeFile("main.nim", "import c21\necho x21\n")
timed "nim ic main.nim"
run "./main"

setCurrentDir getTempDir()
removeDir dir
