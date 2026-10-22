# Changesets and the in-memory Repo.

def post_params(title : String, body : String) : Hash(String, String)
  p = Hash(String, String).new
  p["title"] = title
  p["body"] = body
  p["admin"] = "true"
  p
end

def post_changeset(p : Hash(String, String)) : Bunny::Changeset
  Bunny::Changeset.cast(p, ["title", "body"])
    .validate_required(["title"])
    .validate_length("title", 3, 20)
    .validate_format("body", "@")
end

def test_cast_drops_unpermitted
  cs = Bunny::Changeset.cast(post_params("hey", "x@y"), ["title", "body"])
  assert !cs.changes.has_key?("admin"), "admin not permitted"
  assert_equal "hey", cs.changes["title"]
end

def test_validations
  ok = post_changeset(post_params("hello", "a@b"))
  assert ok.valid?, "valid"
  bad = post_changeset(post_params("", "nope"))
  assert !bad.valid?, "invalid"
  assert_equal "can't be blank", bad.error_for("title")
  assert_equal "has invalid format", bad.error_for("body")
  short = post_changeset(post_params("hi", "a@b"))
  assert_equal "should be at least 3 character(s)", short.error_for("title")
end

def test_validate_number
  p = Hash(String, String).new
  p["age"] = "abc"
  cs = Bunny::Changeset.cast(p, ["age"]).validate_number("age", 0, 150)
  assert_equal "is not a number", cs.error_for("age")
  p["age"] = "200"
  cs2 = Bunny::Changeset.cast(p, ["age"]).validate_number("age", 0, 150)
  assert_equal "must be between 0 and 150", cs2.error_for("age")
end

def test_repo_crud
  repo = Bunny::Repo.new(Bunny::MemoryAdapter.new)
  r = repo.insert("posts", post_changeset(post_params("hello", "a@b")))
  assert r.ok?, "inserted"
  id = r.record.not_nil!.id
  assert_equal 1_i64, id
  repo.insert("posts", post_changeset(post_params("second", "c@d")))
  assert_equal 2, repo.all("posts").size
  got = repo.get("posts", id).not_nil!
  assert_equal "hello", got["title"]
  upd = repo.update("posts", id, Bunny::Changeset.cast(post_params("changed", "e@f"), ["title"]))
  assert upd.ok?, "updated"
  assert_equal "changed", repo.get("posts", id).not_nil!["title"]
  assert_equal 1, repo.where("posts", "title", "second").size
  assert repo.delete("posts", id), "deleted"
  assert repo.get("posts", id).nil?, "gone"
end

def test_repo_rejects_invalid
  repo = Bunny::Repo.new(Bunny::MemoryAdapter.new)
  r = repo.insert("posts", post_changeset(post_params("", "x")))
  assert !r.ok?, "invalid insert rejected"
  assert_equal 0, repo.all("posts").size
end
