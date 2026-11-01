# Learning std/tables
# A typical session with one standard library module: each cell adds a little on
# top of the earlier ones. std/tables is generic, so later cells pay for new
# instantiations. Cell 1 imports and re-exports it, so the import cost is one spike.

# %% import std/tables
import std/tables
export tables
var ages* = initTable[string, int]()

# %% add two entries
ages["ada"] = 36
ages["alan"] = 41
echo ages

# %% length and membership
echo ages.len, " ", "ada" in ages

# %% a default for a missing key
echo ages.getOrDefault("grace", -1)

# %% add and iterate
ages["grace"] = 85
for name, age in ages:
  echo name, " is ", age

# %% a CountTable
var letters* = initCountTable[char]()
for c in "mississippi":
  letters.inc c
echo letters

# %% the most common letter
echo letters.largest

# %% sort by count
letters.sort()
echo letters

# %% an OrderedTable keeps insertion order
let numbers* = {"one": 1, "two": 2, "three": 3}.toOrderedTable
echo numbers

# %% keys in order
for k in numbers.keys:
  echo k

# %% an object as key
import std/hashes
type Point* = object
  x*, y*: int
proc hash*(p: Point): Hash = hash((p.x, p.y))
var grid* = initTable[Point, char]()

# %% fill the grid
grid[Point(x: 0, y: 0)] = 'a'
grid[Point(x: 1, y: 2)] = 'b'
echo grid.len

# %% look up a point
echo grid.getOrDefault(Point(x: 1, y: 2), '.'), grid.getOrDefault(Point(x: 5, y: 5), '.')

# %% a word count proc
import std/strutils
proc wordCount*(s: string): CountTable[string] =
  for w in s.splitWhitespace:
    result.inc w

# %% use it
let words* = wordCount("the cat and the hat and the bat")
echo words.largest, " ", words["and"]

# %% delete a key
ages.del "alan"
echo ages

# %% keys as a seq
import std/sequtils
echo toSeq(ages.keys).len

# %% mgetOrPut to build a table of seqs
var groups* = initTable[string, seq[int]]()
for i in 1 .. 6:
  groups.mgetOrPut(if i mod 2 == 0: "even" else: "odd", @[]).add i
echo groups

# %% equality
echo ages == {"ada": 36, "grace": 85}.toTable

# %% ref tables share
let shared* = newTable[string, int]()
shared["x"] = 1
let alias = shared
alias["x"] = 2
echo shared["x"]
