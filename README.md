# Bunny Framework

A full-stack web framework for [Alice](https://alice-lang.org/), the .NET language with Ruby syntax.

Bunny takes the **developer experience of Ruby on Rails** (generators, conventions, one CLI for
everything) and the **runtime model of the [Phoenix Framework](https://www.phoenixframework.org/)**
(plug pipelines, routers with scopes, channels, PubSub, presence, server-rendered live views).
Phoenix's influence is the larger one: Bunny is built around a single explicit `Conn` that flows through
small functions, and around long-lived realtime connections, not around implicit magic.

The core is called **Bunny Hole**: the request goes in at the top and falls through plugs, the router and
a controller until a response comes out the bottom.

```text
Kestrel ─▶ BunnyServer (HTTP/1.1 + WebSocket) ─▶ Endpoint plugs ─▶ Router ─▶ pipeline ─▶ Controller ─▶ View/Template ─▶ response
                                     │
                                     └─ upgrade ─▶ BunnyLive (Channels · PubSub · Presence · LiveView)
```

## Why

| Goal | How Bunny reaches it |
|---|---|
| Rails-level productivity | `bunny new`, `bunny gen.*` generators, conventions over configuration |
| Phoenix-level realtime | Channels, PubSub, Presence and LiveView in the box, one WebSocket per client |
| High performance | Alice compiles to .NET IL (or NativeAOT); Kestrel transport, pre-compiled route tables, templates parsed once and cached, LiveView sends only the dynamic parts that changed |
| Explicit data flow | Everything is a `Conn -> Conn` transformation; no hidden globals |
| Modular | Six packages with one-way dependencies, checked by an architecture test |
| Low maintenance | Standard library and .NET BCL first; no extra runtime dependencies |

## Packages

| Package | Module | Role |
|---|---|---|
| `packages/shared` | `BunnyKit` | Wire primitives: HTTP reasons, MIME types, HTML escape, URL/query, JSON |
| `packages/core` | `Bunny` | **Bunny Hole**: `Conn`, plugs, pipelines, router, controllers, EAL templates, endpoint, data (repo/changesets) |
| `packages/realtime` | `BunnyLive` | WebSocket protocol, PubSub, Channels, Presence, LiveView |
| `packages/proxy` | `BunnyServer` | Transport: Kestrel (NuGet) for HTTP/1.1 and WebSockets, adapted to `Bunny::Conn` |
| `packages/api` | `BunnyApi` | JSON API helpers: JSON rendering, error shapes, pagination |
| `packages/controller` | `BunnyCli` | The `bunny` command line |

Dependency direction (enforced by tests):

```text
shared <- core <- api
               <- realtime
               <- proxy
               <- controller
```

Entrypoint packages never depend on each other. An application is the composition root that wires them.

## The CLI

```bash
bunny new blog                 # new application
cd blog
bunny server                   # run the app (http://localhost:4000)
bunny routes                   # print the route table
bunny gen.controller Posts index show
bunny gen.live Counter         # LiveView module + template
bunny gen.channel Room         # channel module
bunny gen.resource Post title:string body:text   # schema + controller + views + routes hint
bunny test                     # alice test
bunny version
```

## A tour

### Router (Phoenix style)

```alice
router = Bunny::Router.new
router.pipeline("browser") do |p|
  p.plug(Bunny::Plugs::Logger.new)
  p.plug(Bunny::Plugs::PutSecureHeaders.new)
end
router.scope("/", "browser") do |r|
  r.get("/", ->(c : Bunny::Conn) { PageController.new.index(c) })
  r.get("/posts/:id", ->(c : Bunny::Conn) { PostController.new.show(c) })
end
```

Routes are compiled into a segment tree once at boot. Matching is a walk over path segments, without regex.

### Controllers

```alice
class PostController < Bunny::Controller
  def show(c : Bunny::Conn) : Bunny::Conn
    c.assign("id", c.param("id"))
    render(c, "posts/show")
  end
end
```

`Conn` is the one value that carries request, params, assigns and the response. Helpers: `text`, `html`,
`json`, `redirect`, `put_status`, `put_resp_header`, `halt`.

### Templates (EAL: Embedded Alice, `.html.eal`)

Templates are separate files, `templates/posts/show.html.eal`:

```erb
<%@ title : String, posts : List(Post) %>
<h1><%= title %></h1>
<% for p in posts %>
  <li><%= p.title %></li>
<% end %>
<%== raw_html %>
```

`<%= %>` is HTML-escaped and `<%== %>` is raw. `<% %>` is any Alice code. `<%@ %>` declares typed assigns.
`bunny compile` turns every template into a real Alice class (`PostsShowView < Bunny::View`), so
templates are type-checked and optimized by the Alice compiler, with no interpreter at runtime. Each one
is split into statics and dynamics, and LiveView sends only the dynamics that changed.

### Channels and PubSub

```alice
class RoomChannel < BunnyLive::Channel
  def join(topic : String, payload : Hash(String, Object), s : BunnyLive::Socket) : Bool
    true
  end
  def handle_in(event : String, payload : Hash(String, Object), s : BunnyLive::Socket)
    broadcast(s, "new_msg", payload)
  end
end
```

The wire format is Phoenix's V2 JSON array, `[join_ref, ref, topic, event, payload]`, so Phoenix
JavaScript clients can talk to Bunny.

### LiveView

```alice
class CounterLive < BunnyLive::LiveView
  def mount(s : BunnyLive::LiveSocket)
    s.assign("count", 0)
  end
  def handle_event(event : String, params : Hash(String, Object), s : BunnyLive::LiveSocket)
    s.assign("count", s.get_i("count") + 1) if event == "inc"
  end
end
```

```erb
<%# templates/live/counter.html.eal %>
<%@ count : Int32 %>
<p><%= count %></p><button bunny-click="inc">+</button>
```

The first request renders full HTML. The browser then joins over WebSocket (`/bunny.js`, with no build
step). Events go up and diffs come back.

### Data

`Bunny::Repo` stores records through an adapter (in-memory included). `Bunny::Changeset` casts and
validates params before anything is written (`validate_required`, `validate_length`, `validate_format`).

## Build from source

Requirements: [Alice](https://alice-lang.org/) 0.12+ and the .NET 10 SDK.

```bash
git clone https://github.com/kleeedolinux/bunnyframework
cd bunnyframework
for p in packages/*; do (cd $p && alice test); done   # all tests
cd packages/controller && alice build --release       # the bunny CLI
```

## Project layout

```text
alice.toml            workspace
packages/*            the six packages (see above)
examples/hello        example app: the composition root wiring every package
archicture/           architecture map, ADRs, module notes
CHANGELOG.md
```

## Status

Version `0.10.x`. The APIs are young and may change. See `CHANGELOG.md`.

## License

MIT
