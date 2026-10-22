#!/bin/sh
# Builds the bunny CLI and links it into ~/.local/bin.
set -e
root=$(cd "$(dirname "$0")/.." && pwd)
(cd "$root/packages/controller" && alice build --release)
mkdir -p "$HOME/.local/bin"
ln -sf "$root/packages/controller/bin/Release/net10.0/bunny" "$HOME/.local/bin/bunny"
echo "installed: $HOME/.local/bin/bunny (BUNNY_PATH defaults to $root)"
