#!/bin/sh
# Stands in for the C compiler and linker during a benchmark: runs the real one
# ($CICAK_CC, default gcc) and appends "<cc|link> <start ns> <end ns>" to $CICAK_CCLOG,
# so the harness can split a compile step into Nim, C compile and link time.
t0=$(date +%s%N)
"${CICAK_CC:-gcc}" "$@"
rc=$?
t1=$(date +%s%N)
kind=link
for a in "$@"; do [ "$a" = "-c" ] && kind=cc; done
[ -n "$CICAK_CCLOG" ] && echo "$kind $t0 $t1" >> "$CICAK_CCLOG"
exit $rc
