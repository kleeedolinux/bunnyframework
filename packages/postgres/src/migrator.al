# Migrations: priv/migrations/*.sql applied in file-name order, each in its own transaction,
# recorded in bunny_schema_migrations. Re-running applies nothing new.
module BunnyPg
  class Migrator
    def initialize(@conn : String, @dir : String)
    end

    def run : List(String)
      applied = List(String).new
      return applied unless System.IO.Directory.Exists(@dir)
      ds = Npgsql.NpgsqlDataSource.Create(@conn)
      c = ds.OpenConnection
      begin
        exec(c, nil, "CREATE TABLE IF NOT EXISTS bunny_schema_migrations (version text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())")
        files = System.IO.Directory.GetFiles(@dir, "*.sql")
        System.Array.Sort(files, System.StringComparer.Ordinal)
        for f in files
          version = System.IO.Path.GetFileName(f)
          next if done?(c, version)
          tx = c.BeginTransaction
          begin
            exec(c, tx, System.IO.File.ReadAllText(f))
            mark(c, tx, version)
            tx.Commit
          rescue e : System.Exception
            tx.Rollback
            raise e
          end
          applied << f
        end
      ensure
        c.Dispose
        ds.Dispose
      end
      applied
    end

    def exec(c : Npgsql.NpgsqlConnection, tx : Npgsql.NpgsqlTransaction?, sql : String) : Nil
      cmd = Npgsql.NpgsqlCommand.new(sql, c, tx)
      begin
        cmd.ExecuteNonQuery
      ensure
        cmd.Dispose
      end
    end

    def done?(c : Npgsql.NpgsqlConnection, version : String) : Bool
      cmd = Npgsql.NpgsqlCommand.new("SELECT 1 FROM bunny_schema_migrations WHERE version = $1", c)
      cmd.Parameters.AddWithValue(version)
      begin
        !cmd.ExecuteScalar.nil?
      ensure
        cmd.Dispose
      end
    end

    def mark(c : Npgsql.NpgsqlConnection, tx : Npgsql.NpgsqlTransaction, version : String) : Nil
      cmd = Npgsql.NpgsqlCommand.new("INSERT INTO bunny_schema_migrations (version) VALUES ($1)", c, tx)
      cmd.Parameters.AddWithValue(version)
      begin
        cmd.ExecuteNonQuery
      ensure
        cmd.Dispose
      end
    end
  end
end
