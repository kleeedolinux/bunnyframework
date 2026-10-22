# 0001 - Alice workspace with six packages
Status: accepted
Context: Bunny is written in Alice. AGENTS.md prescribes `crates/{shared,core,realtime,proxy,api,controller}` for Rust. Alice modules compile to `partial static class`, which cannot span assemblies.
Decision: one Alice workspace, `packages/<name>` with the prescribed names. Root modules: shared=`BunnyKit`, core=`Bunny` (Bunny Hole), realtime=`BunnyLive`, proxy=`BunnyServer` (HTTP server), api=`BunnyApi`, controller=`BunnyCli` (exe `bunny`). Dependencies via `path`. Direction enforced by an architecture test.
Consequences: users see several module names; each package is independently testable with `alice test`.
