#!/bin/sh
# Clones the pinned dependencies of scenario s2 (arraymancer) into bench/deps.
# Not atlas: the cells are compiled outside the repo, so the harness passes
# these directories as --path: flags (the `# paths:` line of the scenario).
set -e
cd "$(dirname "$0")"
mkdir -p deps
pin() { # name url commit
  if [ ! -d "deps/$1" ]; then git clone -q "$2" "deps/$1"; fi
  git -C "deps/$1" fetch -q --depth 1 origin "$3" 2>/dev/null || true
  git -C "deps/$1" checkout -q "$3"
}
pin Arraymancer https://github.com/mratsim/Arraymancer dcc220c8e3066fe0c89de4e0debc20ea2cb349d6
pin nimblas https://github.com/SciNim/nimblas 93ffdd705496990983eefa0507d52f6a6c533ca7
pin nimlapack https://github.com/SciNim/nimlapack 231430b3d2156f5cbe8fe16bb8967cd9a93964c5
pin nimcuda https://github.com/SciNim/nimcuda 319b8deb31812fd9277c6232f0ae3fca31c6d55d
pin nim-clblast https://github.com/numforge/nim-clblast cdadb10dd85b95c9e7248f0b9661ad1e7616efe6
pin zip https://github.com/nim-lang/zip 1bc02a1d888cedb53075ca81d9fe3553c16ef10a
pin untar https://github.com/dom96/untar b49f6ac94974fe11cb3d396a8a9c533824a497a7
pin stb_image https://github.com/define-private-public/stb_image-Nim ba5f45286bfa9bed93d8d6b941949cd6218ec888
echo "bench/deps ready"
