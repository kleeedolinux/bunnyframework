# Changelog

## 0.10.0 - unreleased
- Workspace with packages shared, core, realtime, proxy, api, controller.
- BunnyKit: HTTP reasons, MIME, HTML escape, URL/query, pure-Alice JSON encode/decode.
- Bunny Hole (core): Conn, plugs, pipelines, router (segment tree, scopes, 404/405), cookies.
- Controller (views + layouts), Endpoint (error handling), plugs: RequestId, SecureHeaders, MethodOverride, Head, Logger, Static.
- Changesets and Repo with a thread-safe in-memory adapter.
- EAL templates (`*.html.eal`) compiled to typed `Bunny::View` classes with a static/dynamic split.
- BunnyServer: Kestrel (NuGet 2.3.0) transport with WebSocket upgrade via `Bunny::Upgrader`/`WsTransport`.
- BunnyLive: PubSub with fork/join fan-out and encode-once envelopes, Phoenix V2 channels, Presence, LiveView (layout-aware, static/dynamic diffs, pure parallel slot diff), `/bunny.js` client.
- BunnyApi: JSON error and changeset error shapes, pagination, CORS, bearer auth.
- `bunny` CLI: new, server, compile, routes, test, gen.controller/live/channel/resource, arch, version.
- RULES.al/PROOF.al in shared, core, realtime, api: 14 rules proven by exhaustion (escaping, JSON, EAL split, fan-out, LiveView diffs, pagination); `bunny prove [--check]`.
- BunnyPg: PostgreSQL 17 adapter (Npgsql 10.0.3) and transactional SQL migrations; `bunny migrate`, `gen.migration`; `gen.resource` writes a migration; apps use PostgreSQL when `DATABASE_URL` is set; docker-compose with postgres:17.6.
- Signed-cookie sessions, flash, CSRF protection (`Plugs::Session`, `Plugs::Csrf`, `before_send` hooks); constant-time `Secure.equal?` proven; generated apps wire them in.
- `scripts/e2e/liveview.mjs`: real-browser LiveView check over CDP.
- `examples/hello` generated app (`scripts/regen-example.sh`); `scripts/install.sh`, `scripts/test.sh`.
