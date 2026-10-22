# Architecture map

| Path | Content |
|---|---|
| `adr/` | decisions, monotonic numbers |
| `modules/` | one note per package |

Invariants:
- dependency direction `shared <- core <- {api, realtime, proxy, controller}`; entrypoints never depend on each other
- each package owns one root Alice module (modules are partial static classes; they cannot span assemblies)
- no class named like a .NET type in default usings (`Version`, `Action`, `Task`...): Alice treats it as an extension
- classes meant to be subclassed by apps must be `abstract` (Alice seals other classes not subclassed in their own assembly)
- overridable hooks with default bodies are not virtual across assemblies: make them `abstract` (regression test: `packages/realtime/test/hooks_test.al`)
- `alice fmt` reflows heredoc bodies: heredoc asset files (`realtime/src/assets.al`, `controller/src/cli/templates.al`) are fmt-exempt; `scripts/test.sh` checks the rest
- correctness kernels are pure and proven: see `adr/0005-rules-and-proofs.md`; run `bunny prove --check` before committing
- zero-arg `?` methods of another package must be called with `()` (e.g. `result.ok?()`)
