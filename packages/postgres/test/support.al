# PostgreSQL 17 integration tests: `docker compose up -d --wait postgres` first.
def pg_url : String
  System.Environment.GetEnvironmentVariable("BUNNY_PG_URL") || "Host=127.0.0.1;Port=55417;Username=bunny;Password=bunny;Database=bunny_test"
end

# Unique table name per test run so tests stay isolated and repeatable.
def fresh_table : String
  "posts_" + System.Guid.NewGuid.ToString("N").Substring(0, 10)
end

def migrations_for(table : String) : String
  dir = System.IO.Path.Combine(System.IO.Path.GetTempPath, "bunny-mig-" + System.Guid.NewGuid.ToString("N"))
  System.IO.Directory.CreateDirectory(dir)
  System.IO.File.WriteAllText(System.IO.Path.Combine(dir, "0001_create_" + table + ".sql"), "CREATE TABLE " + table + " (id bigserial PRIMARY KEY, title text NOT NULL, views integer NOT NULL DEFAULT 0, published boolean NOT NULL DEFAULT false);")
  System.IO.File.WriteAllText(System.IO.Path.Combine(dir, "0002_index_" + table + ".sql"), "CREATE INDEX " + table + "_title ON " + table + " (title);")
  dir
end
