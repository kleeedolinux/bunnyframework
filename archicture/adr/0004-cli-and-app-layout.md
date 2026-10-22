# 0004 - CLI generates apps; apps are the composition root
Status: accepted
Context: Entrypoint packages must not depend on each other, yet an app needs core, realtime, proxy and api together.
Decision: `bunny` (controller) only generates files, compiles EAL and shells out to `alice run|test`. Each generated app is its own Alice exe that depends on the packages by path and wires them in `src/main.al`. `bunny routes` runs the app with the `routes` argument.
Consequences: the CLI never links app code; dependency rules stay acyclic; apps inside the repo use relative paths, others absolute (`--bunny-path` or `BUNNY_PATH`).
