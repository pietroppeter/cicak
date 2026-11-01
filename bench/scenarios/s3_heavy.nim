# Compute something heavy, then explore it
# Cell 2 simulates particles bouncing in a box (about a second in release mode),
# the other cells look at the result. Re-running pays for the simulation in every
# cell; hot reloading keeps it.

# %% the simulation
import std/[random, math, algorithm, strutils, sequtils]
export random, math, algorithm, strutils, sequtils
type Particle* = object
  x*, y*, vx*, vy*: float
proc simulate*(n, steps: int): seq[Particle] =
  var r = initRand(42)
  result = newSeq[Particle](n)
  for p in result.mitems:
    p = Particle(x: r.rand(1.0), y: r.rand(1.0), vx: r.rand(-1.0 .. 1.0), vy: r.rand(-1.0 .. 1.0))
  for s in 1 .. steps:
    for p in result.mitems:
      p.vy -= 0.01
      p.x += p.vx * 0.01
      p.y += p.vy * 0.01
      if p.x < 0 or p.x > 1: p.vx = -p.vx
      if p.y < 0:
        p.y = -p.y
        p.vy = -p.vy * 0.9
proc f*(x: float): string = formatFloat(x, ffDecimal, 4)

# %% run it
let ps* = simulate(100_000, 2_000)
echo ps.len, " particles"

# %% mean height
echo f(ps.mapIt(it.y).sum / ps.len.float)

# %% highest
echo f(ps.mapIt(it.y).max)

# %% speed of a particle
proc speed*(p: Particle): float = sqrt(p.vx * p.vx + p.vy * p.vy)

# %% mean speed
echo f(ps.mapIt(it.speed).sum / ps.len.float)

# %% fastest three
echo ps.mapIt(it.speed).sorted(Descending)[0 .. 2].mapIt(f(it))

# %% how many left the box sideways
echo ps.countIt(it.x < 0 or it.x > 1)

# %% a histogram of heights
proc histogram*(xs: seq[float], bins: int, hi: float): seq[int] =
  result = newSeq[int](bins)
  for x in xs:
    result[min(bins - 1, int(x / hi * bins.float))].inc

# %% heights in 10 bins
echo histogram(ps.mapIt(it.y), 10, ps.mapIt(it.y).max)

# %% the slow ones, a derived object
let slow* = ps.filterIt(it.speed < 0.2)
echo slow.len

# %% their mean height
echo f(slow.mapIt(it.y).sum / max(1, slow.len).float)

# %% kinetic energy
echo f(ps.mapIt(0.5 * it.speed ^ 2).sum)

# %% potential energy (g = 1 in these units)
echo f(ps.mapIt(it.y).sum)

# %% the leftmost particle
echo f(ps.mapIt(it.x).min)

# %% moving up or down
echo ps.countIt(it.vy > 0), " up, ", ps.countIt(it.vy <= 0), " down"

# %% sort a copy by height
let byHeight* = ps.sortedByIt(it.y)
echo f(byHeight[0].y), " .. ", f(byHeight[^1].y)

# %% median height
echo f(byHeight[byHeight.len div 2].y)

# %% quartiles
echo [1, 2, 3].mapIt(f(byHeight[byHeight.len * it div 4].y))

# %% done
echo "explored ", ps.len, " particles in 20 cells"
