# Architecture map

| Path | Content |
|---|---|
| `adr/` | decisions, monotonic numbers |
| `modules/` | one note per package |

Invariants:
- dependency direction `shared <- core <- {api, realtime, proxy, controller}`; entrypoints never depend on each other
- each package owns one root Alice module (modules are partial static classes; they cannot span assemblies)
- no class named like a .NET type in default usings (`Version`, `Action`, `Task`...): Alice treats it as an extension
