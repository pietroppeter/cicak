# Changelog

Notable changes. An entry is added when a change is implemented, usually when its
OpenSpec change is archived. Format based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- Project setup: atlas, Nim 2.4, OpenSpec, a nimib dev log with the research post and
  the hot code reloading proof of concept, experiments `hcr-cells` and `ic-chain` (#1)
- Dev log post on cicak, the name of the REPL, with range maps and a video
- Benchmark (`bench/`): four scenarios of cells in every mode (`nim c`/`nim ic`, re-run
  or hot reload) and build mode, with compile time split into Nim, C compile and link,
  a design doc and a results page with nim-plotly charts; not run on CI
- Experiment `hcr-ic`: why hot code reloading with `nim ic` does not link on Nim 2.4
- Dev log post "Faster CI": how the site's CI went from about 9 minutes to 1
- Dev log post on the first benchmark runs, with snapshots of the charts it discusses
- Dev log index: a table of living documents (benchmark results, design and scenarios,
  specs, backlog) above the posts; the README lists them too

### Changed
- The benchmark results page no longer carries the findings of the first run: they
  moved to the dev log post, and the page says it is a living document
- The project is now called cicak: repository, nimble package, README and dev log
- Dev log: every page links to the repository, posts link back to the index, and the
  index is a table of posts with date, title and summary
- The second dev log post is now "A working PoC with Hot Code Reloading and Incremental
  Compilation", and the research post links to it
- Experiments run with Nim programs (`run.nim`) instead of shell scripts; a failing or
  hanging experiment now fails the docs build
- CI: the Nim build cache is saved again (it never was, so every run rebuilt Nim), jobs
  have time limits, new pushes cancel a PR's older run, and the OpenSpec review uses Nim 2.4
- CI is faster: Nim comes from the 2.4.0 release tarball (cached by its sha256) instead
  of a ~7 min build from source whenever the `version-2-4` branch moved, and `nim docs`
  renders the posts, the index and the benchmark pages in one program (`docs/all.nim`)

### Fixed
- Nim code on the dev log and benchmark pages is highlighted again: files shown with
  `nbFile` and ```` ```nim ```` fences were left plain; all Nim code is now highlighted
  when the page is built, without highlight.js
- The dev log, benchmark and OpenSpec review pages load nothing from a CDN: fonts, highlight.js (for
  shell snippets) and plotly.js are vendored in `docs/assets` by
  `tools/vendor-assets.sh` and served from the site
