#!/bin/sh
# Time `nim ic` on a chain of 20 cell modules, then on adding a 21st cell.
# Needs Nim >= 2.4 built with nifler/nifmake in PATH.
set -e
timed() { s=$(date +%s.%N); "$@" > /dev/null 2>&1; echo "$* took $(echo "$(date +%s.%N) - $s" | bc) s"; }
dir="$(mktemp -d)"
cd "$dir"
printf 'import std/[strutils, tables]\nvar x* = 1\n' > c1.nim
prev=c1
for i in $(seq 2 20); do
  printf 'import %s\nexport %s\nvar x%s* = x + %s\n' "$prev" "$prev" "$i" "$i" > "c$i.nim"
  prev="c$i"
done
printf 'import c20\necho x20\n' > main.nim
timed nim ic main.nim
./main
printf 'import c20\nexport c20\nvar x21* = x20 * 2\n' > c21.nim
printf 'import c21\necho x21\n' > main.nim
timed nim ic main.nim
./main
echo "files in $dir"
