#!/bin/sh
# Rebuilds examples/hello from the generators, so the example always matches `bunny new` + `bunny gen.*`.
set -e
root=$(cd "$(dirname "$0")/.." && pwd)
(cd "$root/packages/controller" && alice build --release >/dev/null)
bunny="$root/packages/controller/bin/Release/net10.0/bunny"
rm -rf "$root/examples/hello"
mkdir -p "$root/examples"
cd "$root/examples"
"$bunny" new hello >/dev/null
cd hello
BUNNY_STAMP=20261022000000 "$bunny" gen.resource Post title:string body:text views:integer >/dev/null
"$bunny" gen.live Clock >/dev/null
"$bunny" gen.channel Room >/dev/null
"$bunny" gen.controller Admin dash >/dev/null
# Wire the generated pieces (the lines each generator prints as its hint).
python3 - <<'PY'
p = "src/router.al"
s = open(p).read()
s = s.replace('      s.get("/counter",', '''      s.get("/posts", ->(c : Bunny::Conn) { PostController.new.index(c) })
      s.get("/posts/new", ->(c : Bunny::Conn) { PostController.new.new_form(c) })
      s.get("/posts/:id", ->(c : Bunny::Conn) { PostController.new.show(c) })
      s.post("/posts", ->(c : Bunny::Conn) { PostController.new.create(c) })
      s.get("/clock", ->(c : Bunny::Conn) { BunnyLive::Live.render(c, "clock") })
      s.get("/admin", ->(c : Bunny::Conn) { AdminController.new.dash(c) })
      s.get("/counter",''')
s = s.replace('    BunnyLive::Live.register("counter",', '''    BunnyLive::Live.register("clock", ->() { ClockLive.new.as(BunnyLive::LiveView) })
    BunnyLive::Live.register("counter",''')
open(p, "w").write(s)
p = "src/main.al"
s = open(p).read()
s = s.replace("  sockets.live\n", '  sockets.live\n  sockets.channel("room:*", ->() { RoomChannel.new.as(BunnyLive::Channel) })\n')
open(p, "w").write(s)
PY
cp "$root/scripts/example/router_test.al" test/router_test.al
"$bunny" compile >/dev/null
echo "examples/hello regenerated"
