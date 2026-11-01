# Changelog

Notable changes. An entry is added when a change is implemented, usually when its
OpenSpec change is archived. Format based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- Project setup: atlas, Nim 2.4, OpenSpec, a nimib dev log with the research post and
  the hot code reloading proof of concept, experiments `hcr-cells` and `ic-chain` (#1)
- Dev log post on cicak, the name of the REPL, with range maps and a video

### Changed
- The project is now called cicak: repository, nimble package, README and dev log
- Dev log: every page links to the repository, posts link back to the index, and the
  index is a table of posts with date, title and summary
- The second dev log post is now "A working PoC with Hot Code Reloading and Incremental
  Compilation", and the research post links to it
- Experiments run with Nim programs (`run.nim`) instead of shell scripts; a failing or
  hanging experiment now fails the docs build
- CI: the Nim build cache is saved again (it never was, so every run rebuilt Nim), jobs
  have time limits, new pushes cancel a PR's older run, and the OpenSpec review uses Nim 2.4
