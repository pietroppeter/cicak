# nim-repl
A Read-Eval-Print-Loop for Nim

AI disclosure: this project is mostly vibed. Currently [level 7](https://www.visidata.org/blog/2026/ai/#level-6%3A-bots-coded%2C-human-understands-mostly) on visidata AI scale: Human specced, bots coded.

Status: research. Nothing to install yet. The findings so far are in [docs/research.nim](docs/research.nim), a [nimib](https://github.com/pietroppeter/nimib) document.
The short version is that each input becomes a Nim module, a long-running process loads it with hot code reloading, and incremental compilation (`nim ic`) keeps each step cheap.

## Setup

This project targets Nim 2.4. `nim ic` needs the `nifler` and `nifmake` tools, which the 2.4.0 release binaries are missing ([forum thread](https://forum.nim-lang.org/t/14255)).
Building Nim from source includes them:

```sh
git clone -b version-2-4 https://github.com/nim-lang/Nim
cd Nim
sh build_all.sh     # builds bin/nim, bin/nifler, bin/nifmake
./koch atlas        # builds bin/atlas
```

Dependencies are managed with [atlas](https://github.com/nim-lang/atlas):

```sh
atlas install
```

## Building the research document

```sh
nim r docs/research.nim   # writes docs/research.html
```

nimib's markdown dependency uses `std/re`, so `libpcre.so.3` must be installed (on Debian/Ubuntu: `apt install libpcre3`).

## Experiments

- [experiments/hcr-cells](experiments/hcr-cells): cells as modules, added to a running process with hot code reloading. `run.sh` starts a host with one cell, then adds two more without restarting it.
- [experiments/ic-chain](experiments/ic-chain): times `nim ic` on a chain of 20 cell modules and on adding a 21st.
