# 0006 - PostgreSQL adapter as its own package
Status: accepted
Context: Persistence must use PostgreSQL 17. Core must stay free of drivers. The adapter is an independently testable boundary (needs a live database).
Decision: `packages/postgres` (`BunnyPg`, depends on core + shared, NuGet Npgsql 10.0.3) implements `Bunny::Adapter` and a SQL-file `Migrator` (ordered, transactional, `bunny_schema_migrations`). Identifiers pass the proven `Ident` kernel; values are untyped bound parameters. Integration tests run against `postgres:17.6` from `docker-compose.yml` (healthcheck `pg_isready`). Apps select it via `DATABASE_URL`.
Consequences: an extra package and NuGet dependency; Repo records stay string-typed (columns typed in SQL).
