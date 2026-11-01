## Scenarios: notebooks of cells in bench/scenarios, the generated s0 and the
## calibration session. Used by the harness (bench.nim) and the scenarios page.

import std/[os, strutils]

type
  Scenario* = object
    id*, title*: string
    description*: string ## header comment lines after the title
    paths*: seq[string]   ## extra --path: dirs, relative to bench/
    cells*: seq[(string, string)]  ## (title, code)

proc loadScenario*(file: string): Scenario =
  ## A scenario is a notebook in jupytext's percent format: `# %% title` starts
  ## a cell. Header comments before the first cell: the title on the first line,
  ## and `# paths: a b` for dependencies (dirs relative to bench/).
  result.id = file.splitFile.name.split('_')[0]
  var inCell = false
  for line in lines(file):
    if line.startsWith("# %%"):
      inCell = true
      result.cells.add (line[4 .. ^1].strip, "")
    elif not inCell:
      if line.startsWith("# paths:"): result.paths = line[8 .. ^1].splitWhitespace
      elif line.startsWith("# ") and result.title == "": result.title = line[2 .. ^1]
      elif line.startsWith("# "): result.description.add line[2 .. ^1] & " "
    else:
      result.cells[^1][1].add line & "\n"
  for c in result.cells.mitems: c[1] = c[1].strip(leading = false)
  result.description = result.description.strip

proc scenario0*(n: int): Scenario =
  ## Integer variables that depend on each other: two of every three cells add
  ## a variable, the latest minus the one before it; the third updates the one
  ## before from the latest. The values cycle between -2 and 2, so any length
  ## stays small. Generated, so it can run to any length.
  result = Scenario(id: "s0", title: "Integer variables (generated)",
                    description: "Two of every three cells add an integer variable, the latest minus the one before it; the third updates an earlier variable from the latest. The values cycle between -2 and 2.")
  var defined: seq[int]
  for i in 1 .. n:
    if i mod 3 == 0:
      let (a, b) = (defined[^2], defined[^1])
      result.cells.add ("update x" & $a, "x" & $a & " = x" & $b & " - x" & $a &
                        "\necho \"x" & $a & " = \", x" & $a)
    else:
      let rhs = case defined.len
        of 0: "1"
        of 1: "x" & $defined[^1] & " + 1"
        else: "x" & $defined[^1] & " - x" & $defined[^2]
      result.cells.add ("add x" & $i, "var x" & $i & "* = " & rhs & "\necho \"x" & $i & " = \", x" & $i)
      defined.add i

proc independent0(n: int): seq[(string, string)] =
  ## The first version of s0 (independent variables), kept for calibration so
  ## that references stay comparable across runs.
  for i in 1 .. n:
    if i mod 3 == 0:
      let j = i - 2
      result.add ("assign x" & $j, "x" & $j & " = x" & $j & " + " & $i & "\necho \"x" & $j & " = \", x" & $j)
    else:
      result.add ("add x" & $i, "var x" & $i & "* = " & $i & "\necho \"x" & $i & " = \", x" & $i)

proc calibration*(): Scenario =
  ## The same small session in every run, at its start and at its end: the
  ## environment's reference time, phase by phase (see DESIGN.md). Ten cells of
  ## the first s0, then one cell with a fixed CPU-bound loop, run once, for the run phase.
  result = Scenario(id: "cal", title: "Calibration", cells: independent0(10),
                    description: "Run at the start and end of every run (c+rerun, debug): ten cells adding and assigning independent integer variables, then a fixed computation that runs once.")
  result.cells.add ("fixed computation", """var acc* = 0'u64
for i in 0'u64 ..< 300_000_000'u64:
  acc = acc * 6364136223846793005'u64 + i
echo acc""")
