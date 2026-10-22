# Changelog

## 0.10.0 - unreleased
- Workspace with packages shared, core, realtime, proxy, api, controller.
- BunnyKit: HTTP reasons, MIME, HTML escape, URL/query, pure-Alice JSON encode/decode.
- Bunny Hole (core): Conn, plugs, pipelines, router (segment tree, scopes, 404/405).
- Controller (views + layouts), Endpoint (error handling), plugs: RequestId, SecureHeaders, MethodOverride, Head, Logger, Static; cookies.
- Changesets and Repo with a thread-safe in-memory adapter.
- BunnyServer: Kestrel (NuGet 2.3.0) transport with WebSocket upgrade via `Bunny::Upgrader`/`WsTransport`.
- BunnyLive: PubSub with fork/join fan-out and encode-once envelopes, Phoenix V2 channels, Presence, LiveView (static/dynamic diffs, pure parallel slot diff), `/bunny.js` client.
- EAL templates (`*.html.eal`) compiled to typed `Bunny::View` classes with a static/dynamic split.
