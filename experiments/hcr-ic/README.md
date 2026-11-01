# Hot code reloading with `nim ic`

Backlog item "HCR together with IC". Investigated 2026-11-01 with the Nim 2.4.0
linux_x64 tarball (compiled 2026-10-28); the live
[cicak-app](https://cicak.pietroppeter.xyz), built from the `version-2-4` branch,
fails the same way.

**Short answer: it is an unsupported combination, not a missing flag.** `nim ic`'s
per-module C backend (`compiler/nifbackend.nim`) was written without hot code
reloading in mind, and there are at least two independent places where it breaks.
`nim c --hotcodereloading:on` and `nim ic` without HCR both work.

## Reproduce

```sh
nim r experiments/hcr-ic/run.nim        # or: ... run.nim /path/to/nim
```

A host that imports one cell module, built twice. `nim c` builds it; `nim ic` fails
when `nim nifc --icBackendStage:link` links the main module's shared library:

```
@mhost.nim.c:(.text+0x26c): undefined reference to `Init000'
lib@mhost.nim.c.so.tmp: hidden symbol `Init000' isn't defined
nifmake: command failed (exit code 1): nim nifc ... --icBackendStage:link ...
```

## Why

How HCR is meant to work (`nim c`): every module becomes its own shared library.
Each library exports `HcrGetImportedModules` (a list of the libraries it imports,
built from `graph.importDeps`) and unmangled `Init000` / `DatInit000` /
`HcrInit000` entry points. The executable calls only `hcrInit`, which walks those
lists, loads every library and calls its init procs through `dlsym`. Procs are
called through pointers registered with `hcrRegisterProc`, so a reload can swap
them. In `cgen.registerModuleToMain`, the HCR branch therefore registers *nothing*
in NimMain for the other modules.

### Layer 1: NimMain calls every module's init directly

`nifbackend.cgFinishModule` (main module's `cg` stage) calls
`registerReusedModuleToMain` for every module, which mirrors the non-HCR path (its
doc comment says so: "reuse is disabled when hcr is on"). Under HCR the init names
are not module-prefixed (`getSomeInitName` drops the prefix), so `PreMainInner`
ends up calling `Init000()` and `DatInit000()` once per module: undefined, and
ambiguous anyway. This is the error above.

### Layer 2: the modules' import lists are empty

Each `cg` process loads modules from NIF instead of running sem, so
`graph.importDeps` is empty and every `hcr_module_list` is `{""}`. The main
module's list has only `system`; `cell_1` is never listed. Even if it linked,
`hcrInit` would never load or initialize the cells, and `performCodeReload` would
have nothing to reload.

[`nifbackend-hcr.patch`](nifbackend-hcr.patch) fixes both layers (skip the direct
registration when HCR is on; rebuild `importDeps` from each target's
`PrecompiledModule.deps`). With it, the `Init000` error is gone and the main
module's list is right, and the build gets one step further:

### Layer 3: a module's proc bodies end up in another module's library

```
@msyscxmyj9.nim.c: in function `DatInit000':
undefined reference to `eqdestroy__u1009940979__syscxmyj9___..._actual'
relocation R_X86_64_PC32 against undefined hidden symbol ... when making a shared object
```

`system`'s `DatInit000` registers `=destroy` for a `seq` with `hcrRegisterProc`, as
HCR requires of the owner module. But the body (`..._actual`) was emitted in
`assertions`' translation unit: IC generates on demand ("emit-everywhere") and its
`merge` stage picks one translation unit per unique definition, which is fine when
everything ends in one executable. With HCR each translation unit is a separate
shared library that has to contain the bodies it registers, so that link fails.
Fixing this means making the `merge` stage (or `findPendingModule`) put every
definition in its owner module when HCR is on, and checking the link stage
produces the executable plus one library per module as `nim c` does. That is a
compiler change of real size, not a quick patch.

## Upstream

No issue or PR in nim-lang/Nim mentions HCR with `nim ic` (searched 2026-11-01:
"hotcodereloading ic", "hcr ic", "hcr nifc", "Init000", issues and PRs). Related:
HCR itself is deprecated
([RFC #573](https://github.com/nim-lang/RFCs/issues/573), the compiler warns), and
open HCR work is [#26581](https://github.com/nim-lang/Nim/pull/26581) (arm64 glibc
jump table) and [#26592](https://github.com/nim-lang/Nim/pull/26592) (refuse a
reload whose global types changed). An issue with `run.nim` and the three layers
would be the next step if HCR + IC matters to cicak.

## What cicak does meanwhile

- cicak-app refuses hot reload + `nim ic` at once with an explanation instead of
  spending ~5 s on a build that cannot link.
- For a REPL, the two halves can be had separately: `nim ic` makes re-compiling the
  whole program cheap (about 0.35 s per new cell after a ~5 s cold build, see
  `ic-chain`), and HCR with `nim c` keeps state (about 0.8 to 1 s per cell). The
  re-run strategy with `nim ic` is the main alternative to HCR to measure.
