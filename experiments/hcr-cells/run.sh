#!/bin/sh
# Cells as modules with hot code reloading: start a host with one cell,
# then add c2 and c3 to the running process. Needs Nim >= 2.4 in PATH.
set -e
cd "$(dirname "$0")"
LIB="$(dirname "$(dirname "$(command -v nim)")")/lib"
F="--hints:off --warnings:off"
nim c $F --app:lib -d:createNimRtl --out:libnimrtl.so "$LIB/nimrtl.nim"
nim c $F --app:lib -d:createNimHcr --out:libnimhcr.so "$LIB/nimhcr.nim"
printf 'import c1\n' > cells.nim
rm -f go
nim c $F --hotcodereloading:on --out:host main.nim
LD_LIBRARY_PATH=$PWD ./host &
sleep 2
for cells in "c1, c2" "c1, c2, c3"; do
  printf 'import %s\n' "$cells" > cells.nim
  # the running host's executable can't be overwritten; the cell libraries are what matter
  nim c $F --hotcodereloading:on --out:host.next main.nim
  touch go
  sleep 2
done
wait
printf 'import c1\n' > cells.nim
