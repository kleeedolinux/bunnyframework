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
| High performance | Kestrel transport; routes compiled into a segment tree; EAL templates compiled to Alice classes; pure-Alice JSON; fork/join PubSub fan-out with encode-once frames; LiveView sends only changed slots |
| Explicit data flow | Everything is a `Conn -> Conn` transformation; no hidden globals |
| Modular | Six packages with one-way dependencies, checked by an architecture test |
| Low maintenance | Pure Alice wherever possible; the only NuGet dependency is Kestrel |

## Packages

| Package | Module | Role |
|---|---|---|
| `packages/shared` | `BunnyKit` | Wire primitives: HTTP reasons, MIME types, HTML escape, URL/query, JSON |
| `packages/core` | `Bunny` | **Bunny Hole**: `Conn`, plugs, pipelines, router, controllers, EAL templates, endpoint, data (repo/changesets) |
| `packages/realtime` | `BunnyLive` | WebSocket protocol, PubSub, Channels, Presence, LiveView |
| `packages/proxy` | `BunnyServer` | Transport: Kestrel (NuGet) for HTTP/1.1 and WebSockets, adapted to `Bunny::Conn` |
| `packages/api` | `BunnyApi` | JSON API helpers: error shapes, pagination, CORS, bearer auth |
| `packages/controller` | `BunnyCli` | The `bunny` command line |

Dependency direction (enforced by tests):

```text
shared <- core <- api
               <- realtime
               <- proxy
               <- controller
```

Entrypoint packages never depend on each other. An application is the composition root that wires them.

## Install

Requirements: [Alice](https://alice-lang.org/) 0.12+ and the .NET 10 SDK.

```bash
git clone https://github.com/kleeedolinux/bunnyframework
cd bunnyframework
scripts/install.sh            # builds the CLI, links ~/.local/bin/bunny
```

## The CLI

```bash
bunny new blog                 # new application
cd blog
bunny server                   # compile templates + run (PORT=4000, BUNNY_ENV=prod hides error details)
bunny routes                   # print the route table
bunny compile                  # templates/**/*.html.eal -> src/_eal/
bunny gen.controller Posts index show
bunny gen.live Clock           # LiveView + template
bunny gen.channel Room         # channel
bunny gen.resource Post title:string body:text views:integer   # CRUD controller + templates + route lines
bunny test                     # compile templates + alice test
bunny arch                     # check the framework's dependency rules
```

A new app:

```text
src/main.al            composition root: endpoint plugs, sockets, server
src/router.al          module App: pipelines, scopes, routes, PubSub, Repo
src/controllers/       controllers
src/live/              LiveViews
templates/             *.html.eal (layouts/app, page/home, live/counter)
src/_eal/              generated view classes (git-ignored)
priv/static/           static files at /static
test/                  alice tests
```

## A tour

### Router (Phoenix style)

```alice
router = Bunny::Router.new
router.pipeline("browser") do |p|
  p.plug(Bunny::Plugs::SecureHeaders.new)
  p.plug(->(c : Bunny::Conn) { Bunny::Controller.put_layout(c, "layouts/app") })
end
router.scope("/", ["browser"]) do |r|
  r.get("/", ->(c : Bunny::Conn) { PageController.new.home(c) })
  r.get("/posts/:id", ->(c : Bunny::Conn) { PostController.new.show(c) })
  r.get("/files/*path", ->(c : Bunny::Conn) { c.text(c.param("path")) })
end
```

Routes are compiled into a segment tree at boot (static > `:param` > `*wildcard`), with no regex. Unknown paths get 404; a known path with the wrong method gets 405 plus `allow`. Pipelines halt on `c.halt`.

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
`json`, `redirect`, `put_status`, `put_resp_header`, `put_resp_cookie`, `halt`. Params merge path, body
(form or JSON) and query. Built-in plugs: `RequestId`, `SecureHeaders`, `MethodOverride`, `Head`,
`Logger`, `Static`. The `Endpoint` turns exceptions into 500s (with details when `debug`).

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
  def handle_in(event : String, payload : Hash(String, Object), s : BunnyLive::Socket) : Object?
    broadcast(s, "new_msg", payload)
    nil                          # or a reply payload
  end
end

sockets.channel("room:*", ->() { RoomChannel.new.as(BunnyLive::Channel) })
```

The wire format is Phoenix's V2 JSON array, `[join_ref, ref, topic, event, payload]`, so Phoenix
JavaScript clients can talk to Bunny. `PubSub.broadcast` encodes the payload once and shares the string
across every socket. Above 64 subscribers it forks with Alice `spawn` and joins the halves (fork/join).
`Presence` tracks keys per topic and broadcasts `presence_diff`.

### LiveView

```alice
class CounterLive < BunnyLive::LiveView
  def template : String
    "live/counter"
  end
  def mount(params : Hash(String, Object), s : BunnyLive::LiveState) : Nil
    s.assign("count", 0)
  end
  def handle_event(event : String, params : Hash(String, Object), s : BunnyLive::LiveState) : Nil
    s.assign("count", s.get("count").as(Int32) + 1) if event == "inc"
  end
  def handle_info(event : String, payload : Object, s : BunnyLive::LiveState) : Nil
  end
end

BunnyLive::Live.register("counter", ->() { CounterLive.new.as(BunnyLive::LiveView) })
r.get("/counter", ->(c : Bunny::Conn) { BunnyLive::Live.render(c, "counter") })
```

```erb
<%# templates/live/counter.html.eal %>
<%@ count : Int32 %>
<p><%= count %></p><button bunny-click="inc">+</button>
```

The first request renders full HTML inside the layout. `/bunny.js` (no build step) then joins
`lv:counter:<id>`. The join reply carries the statics once and the dynamics. Each event
(`bunny-click`, `bunny-submit`, `bunny-change`, `bunny-value-*`) gets back only the slots that changed, e.g.
`{"diff":{"0":"1"}}`. The slot comparison is a `pure def` loop that Alice parallelizes for large views.
`s.subscribe(topic)` routes PubSub messages to `handle_info`, which pushes a diff.

### Data

`Bunny::Repo` stores records through an adapter (in-memory included). `Bunny::Changeset` casts and
validates params before anything is written (`validate_required`, `validate_length`, `validate_format`,
`validate_number`). `BunnyApi::Render.changeset_errors` turns failures into `422 {"errors":{...}}`.

## Performance

Measured with `wrk -t4 -c64 -d5s` on the generated app (debug build, logger on, one machine):

| Route | Requests/s |
|---|---|
| `GET /api/health` (text) | ~184,000 |
| `GET /` (layout + EAL page) | ~177,000 |

## Develop

```bash
scripts/test.sh     # every package suite, architecture check, example app tests
```

Alice notes that shape the code (see `archicture/README.md`): one root module per package; classes
that apps subclass are `abstract`; overridable hooks are abstract, because Alice only emits virtual
methods for abstract or locally overridden ones.

## Project layout

```text
alice.toml            workspace
packages/*            the six packages (see above)
examples/hello        example app: the composition root wiring every package
archicture/           architecture map, ADRs, module notes
scripts/              install.sh, test.sh
CHANGELOG.md
```

## Status

Version `0.10.x`. The APIs are young and may change. See `CHANGELOG.md`.

## License

MIT
