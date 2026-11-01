## Build a hot code reloading host that imports one cell, with `nim c` and with
## `nim ic`. `nim c` works; `nim ic` fails at the nifc link step (see README.md).
## Run with `nim r experiments/hcr-ic/run.nim [path/to/nim]`
## (needs Nim >= 2.4 built with nifler and nifmake).
import std/[os, osproc, strutils, tempfiles]

let nim = if paramCount() >= 1: paramStr(1) else: "nim"
let dir = createTempDir("hcr-ic-", "")
setCurrentDir dir
writeFile("cell_1.nim", "echo \"hello\"\n")
writeFile("cells.nim", "import cell_1\n")
writeFile("host.nim", "import std/hotcodereloading\nimport cells\necho \"ready\"\n")
echo "in ", dir

for compiler in ["c", "ic"]:
  let cmd = nim & " " & compiler & " --hints:off --warnings:off --nimcache:nc_" &
            compiler & " --hotcodereloading:on --out:host_" & compiler & " host.nim"
  let (output, exitCode) = execCmdEx(cmd)
  echo "--- nim ", compiler, ": ", (if exitCode == 0: "ok" else: "failed")
  if exitCode != 0:
    var shown = 0
    for line in output.splitLines:
      if "undefined reference" in line or "isn't defined" in line or "nifmake:" in line:
        echo "  ", line[0 ..< min(line.len, 160)]
        inc shown
        if shown == 4: break
