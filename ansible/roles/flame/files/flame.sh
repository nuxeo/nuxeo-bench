#!/bin/bash
OUT=/tmp/flame.svg
cd /tmp
/bin/rm -f /tmp/perf.data $OUT
perf record -F 99 -a -g -- sleep 30
jmaps
perf script > /tmp/out.stacks
/usr/local/FlameGraph/stackcollapse-perf.pl /tmp/out.stacks | /usr/local/FlameGraph/flamegraph.pl --color=java --hash > $OUT
echo "### done: $OUT"
