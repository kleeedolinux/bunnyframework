#!/bin/sh
# Runs every package test suite, the architecture check and the example app tests.
set -e
root=$(cd "$(dirname "$0")/.." && pwd)
for p in shared core realtime proxy api controller; do
  echo "== $p"
  (cd "$root/packages/$p" && alice test)
done
(cd "$root/packages/controller" && alice build --release >/dev/null)
bunny="$root/packages/controller/bin/Release/net10.0/bunny"
(cd "$root" && "$bunny" arch)
echo "== fmt (heredoc assets exempt: alice fmt reflows heredoc bodies)"
for d in "$root"/packages/* "$root/examples/hello"; do
  (cd "$d" && find src test -name '*.al' -not -path 'src/_eal/*' -not -path 'src/assets.al' -not -path 'src/cli/templates.al' \
    | xargs alice fmt --check >/dev/null)
done
echo "== examples/hello"
(cd "$root/examples/hello" && "$bunny" test)
