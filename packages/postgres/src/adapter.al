# PostgreSQL adapter for Bunny::Repo (Npgsql, pooled data source).
# Values travel as untyped parameters so PostgreSQL coerces them to each column's type.
module BunnyPg
  class PgAdapter < Bunny::Adapter
    getter source : Npgsql.NpgsqlDataSource

    def initialize(conn : String)
      @source = Npgsql.NpgsqlDataSource.Create(conn)
    end

    def param(cmd : Npgsql.NpgsqlCommand, value : String) : Nil
      p = Npgsql.NpgsqlParameter.new
      p.NpgsqlDbType = NpgsqlTypes.NpgsqlDbType.Unknown
      p.Value = value
      cmd.Parameters.Add(p)
    end

    def self.text_of(v : Object) : String
      return v.as(Bool) ? "true" : "false" if v.is_a?(Bool)
      return v.as(System.DateTime).ToString("o") if v.is_a?(System.DateTime)
      return v.as(Float64).ToString("R", System.Globalization.CultureInfo.InvariantCulture) if v.is_a?(Float64)
      return v.as(System.Decimal).ToString(System.Globalization.CultureInfo.InvariantCulture) if v.is_a?(System.Decimal)
      v.to_s
    end

    def read_records(cmd : Npgsql.NpgsqlCommand) : List(Bunny::Record)
      out = List(Bunny::Record).new
      reader = cmd.ExecuteReader
      begin
        while reader.Read
          id = 0_i64
          fields = Hash(String, String).new
          for i in 0...reader.FieldCount
            name = reader.GetName(i)
            next if reader.IsDBNull(i)
            if name == "id"
              id = System.Convert.ToInt64(reader.GetValue(i))
            else
              fields[name] = PgAdapter.text_of(reader.GetValue(i))
            end
          end
          out << Bunny::Record.new(id, fields)
        end
      ensure
        reader.Dispose
      end
      out
    end

    def command(sql : String) : Npgsql.NpgsqlCommand
      @source.CreateCommand(sql)
    end

    def insert(table : String, fields : Hash(String, String)) : Bunny::Record
      t = Ident.check(table)
      cols = List(String).new
      vals = List(String).new
      cmd = command("")
      for k in fields.Keys
        cols << Ident.check(k)
        param(cmd, fields[k])
        vals << "$" + cmd.Parameters.Count.to_s
      end
      sql = cols.size == 0 ? "INSERT INTO #{t} DEFAULT VALUES RETURNING *" : "INSERT INTO #{t} (#{String.Join(", ", cols)}) VALUES (#{String.Join(", ", vals)}) RETURNING *"
      cmd.CommandText = sql
      begin
        read_records(cmd)[0]
      ensure
        cmd.Dispose
      end
    end

    def update(table : String, id : Int64, fields : Hash(String, String)) : Bunny::Record?
      return get(table, id) if fields.size == 0
      t = Ident.check(table)
      sets = List(String).new
      cmd = command("")
      for k in fields.Keys
        param(cmd, fields[k])
        sets << Ident.check(k) + " = $" + cmd.Parameters.Count.to_s
      end
      param(cmd, id.to_s)
      cmd.CommandText = "UPDATE #{t} SET #{String.Join(", ", sets)} WHERE id = $#{cmd.Parameters.Count} RETURNING *"
      begin
        rows = read_records(cmd)
        return nil if rows.size == 0
        rows[0]
      ensure
        cmd.Dispose
      end
    end

    def get(table : String, id : Int64) : Bunny::Record?
      cmd = command("SELECT * FROM #{Ident.check(table)} WHERE id = $1")
      param(cmd, id.to_s)
      begin
        rows = read_records(cmd)
        return nil if rows.size == 0
        rows[0]
      ensure
        cmd.Dispose
      end
    end

    def all(table : String) : List(Bunny::Record)
      cmd = command("SELECT * FROM #{Ident.check(table)} ORDER BY id")
      begin
        read_records(cmd)
      ensure
        cmd.Dispose
      end
    end

    def delete(table : String, id : Int64) : Bool
      cmd = command("DELETE FROM #{Ident.check(table)} WHERE id = $1")
      param(cmd, id.to_s)
      begin
        cmd.ExecuteNonQuery > 0
      ensure
        cmd.Dispose
      end
    end
  end
end
