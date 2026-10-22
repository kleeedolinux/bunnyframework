# Modules

| Package | Module | Owns | Must not |
|---|---|---|---|
| shared | `BunnyKit` | HTTP reasons, MIME, HTML escape, URL/query, JSON | depend on any package |
| core | `Bunny` | Conn, Plug/Pipeline, Router, Controller, Endpoint, plugs, EAL compiler + View runtime, Changeset/Repo, `WsTransport`/`Upgrader` contracts | know Kestrel, WebSocket framing, CLI |
| realtime | `BunnyLive` | PubSub (fork/join fan-out), Socket/Channel (Phoenix V2 wire), Presence, LiveView, `/bunny.js` | depend on proxy/api/controller |
| proxy | `BunnyServer` | Kestrel hosting, Conn <-> HttpContext, `KestrelSocket` | contain request logic |
| api | `BunnyApi` | JSON error shapes, pagination, CORS, bearer auth | depend on realtime/proxy |
| controller | `BunnyCli` (exe `bunny`) | new/compile/server/routes/test/gen.*/arch | link app code; it shells out to `alice` |

App layout made by `bunny new`: `src/main.al` (composition root), `src/router.al` (`App`), `src/controllers`, `src/live`, `src/channels`, `templates/**/*.html.eal`, `src/_eal/` (generated, ignored), `priv/static`.
