# 0002 - EAL: templates compiled to Alice
Status: accepted
Context: Templates must be fast, typed and diffable for LiveView. Runtime-interpreted templates lose types and optimizations.
Decision: templates are separate `*.html.eal` files (Embedded Alice: `<%= %>` escaped, `<%== %>` raw, `<% %>` code, `<%@ name : Type %>` typed assigns). `bunny compile` turns each into a `Bunny::View` subclass. Top-level output tags and top-level blocks are dynamic slots; the text between them is static.
Consequences: a compile step before build; template errors are Alice compile errors; LiveView diffs come from the static/dynamic split.
