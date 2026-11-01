import std/hotcodereloading
import cells
import std/[os]
var i = 0
while i < 2:
  sleep 200
  if fileExists("go"):
    removeFile("go")
    echo "reloading"
    performCodeReload()
    inc i
