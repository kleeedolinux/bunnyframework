require "./support"

def migrated_repo(table : String) : Bunny::Repo
  BunnyPg::Migrator.new(pg_url, migrations_for(table)).run
  Bunny::Repo.new(BunnyPg::PgAdapter.new(pg_url))
end

def params(title : String, views : String) : Hash(String, String)
  p = Hash(String, String).new
  p["title"] = title
  p["views"] = views
  p
end

def test_migrations_apply_once_in_order
  t = fresh_table
  dir = migrations_for(t)
  m = BunnyPg::Migrator.new(pg_url, dir)
  first = m.run
  assert_equal 2, first.size
  assert first[0].EndsWith("0001_create_" + t + ".sql"), first[0]
  assert_equal 0, m.run.size
end

def test_failed_migration_rolls_back
  t = fresh_table
  dir = migrations_for(t)
  System.IO.File.WriteAllText(System.IO.Path.Combine(dir, "0003_bad_" + t + ".sql"), "ALTER TABLE " + t + " ADD COLUMN x int; SELECT broken_syntax(;")
  m = BunnyPg::Migrator.new(pg_url, dir)
  raised = false
  begin
    m.run
  rescue e : Npgsql.PostgresException
    raised = true
  end
  assert raised, "bad migration raises"
  repo = Bunny::Repo.new(BunnyPg::PgAdapter.new(pg_url))
  r = repo.adapter.insert(t, params("ok", "1"))
  assert_equal "", r["x"]
end

def test_crud_with_type_coercion
  t = fresh_table
  repo = migrated_repo(t)
  cs = Bunny::Changeset.cast(params("hello", "42"), ["title", "views"]).validate_required(["title"])
  res = repo.insert(t, cs)
  assert res.ok?(), "inserted"
  rec = res.record.not_nil!
  assert rec.id > 0, "id assigned"
  assert_equal "42", rec["views"]
  assert_equal "false", rec["published"]
  repo.insert(t, Bunny::Changeset.cast(params("second", "1"), ["title", "views"]))
  assert_equal 2, repo.all(t).size
  assert_equal "hello", repo.all(t)[0]["title"]
  upd = repo.update(t, rec.id, Bunny::Changeset.cast(params("changed", "7"), ["title", "views"]))
  assert upd.ok?(), "updated"
  assert_equal "7", repo.get(t, rec.id).not_nil!["views"]
  assert repo.update(t, 999999, Bunny::Changeset.cast(params("x", "1"), ["title"])).record.nil?, "missing row"
  assert repo.delete(t, rec.id), "deleted"
  assert !repo.delete(t, rec.id), "already gone"
  assert repo.get(t, rec.id).nil?, "gone"
end

def test_constraints_enforced_by_postgres
  t = fresh_table
  repo = migrated_repo(t)
  raised = false
  begin
    repo.adapter.insert(t, Hash(String, String).new)
  rescue e : Npgsql.PostgresException
    raised = e.SqlState == "23502"
  end
  assert raised, "NOT NULL violation surfaces"
end

def test_identifiers_are_validated
  repo = Bunny::Repo.new(BunnyPg::PgAdapter.new(pg_url))
  raised = false
  begin
    repo.all("posts; DROP TABLE x")
  rescue e : System.ArgumentException
    raised = true
  end
  assert raised, "unsafe table name rejected"
end
