#!/bin/sh
# Runs the benchmark in Docker, from a clone of the cicak repository:
#
#   bench/docker/run.sh <label> [bench options]
#
# e.g. on the Hetzner VPS, at a quiet hour (it shares the machine with live apps):
#
#   git clone -b <branch> https://github.com/pietroppeter/cicak && cd cicak
#   nohup bench/docker/run.sh hetzner --reps:3 --s0cells:40 > bench.log 2>&1 &
#
# <label> names the environment. Results go to bench/results/<date>-<label>/ in the
# clone: commit them (or send them over) and render the page with `nim r bench/results.nim`.
# It runs s0-s2 in debug and release, then s3 also in danger; options given here are
# added to both runs (a later option wins, so --opts: or --scenarios: can override).
set -e
[ -n "$1" ] || { echo "usage: $0 <label> [bench options]"; exit 1; }
label="$1"; shift
cd "$(dirname "$0")/../.."
docker build -q -t cicak-bench bench/docker
run() {
  docker run --rm -v "$PWD:/cicak" -u "$(id -u):$(id -g)" -e HOME=/tmp cicak-bench sh -c \
    "git config --global --add safe.directory /cicak; bench/deps.sh && nim c -d:release --hints:off -o:/tmp/benchbin bench/bench.nim && /tmp/benchbin --label:$label --work:/tmp/cicak-bench $*"
}
run --scenarios:s0,s1,s2 --opts:debug,release "$@"
run --scenarios:s3 --opts:debug,release,danger "$@"
