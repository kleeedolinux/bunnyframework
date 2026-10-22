# BunnyApi: JSON API conventions.

def test_changeset_errors_shape
  p = Hash(String, String).new
  p["title"] = ""
  cs = Bunny::Changeset.cast(p, ["title"]).validate_required(["title"])
  c = BunnyApi::Render.changeset_errors(Bunny::Conn.new("POST", "/"), cs)
  assert_equal 422, c.status
  assert_equal "{\"errors\":{\"title\":[\"can't be blank\"]}}", c.resp_body
end

def test_error_shape
  c = BunnyApi::Render.error(Bunny::Conn.new("GET", "/"), 404, "not found")
  assert_equal 404, c.status
  assert_equal "{\"error\":{\"status\":404,\"message\":\"not found\"}}", c.resp_body
end

def test_pagination
  items = List(Object).new
  for i in 0...25
    items << i
  end
  page = BunnyApi::Page.from(Bunny::Conn.new("GET", "/?page=3&per_page=10"), items)
  assert_equal 5, page.entries.size
  assert_equal 3, page.total_pages
  assert_equal "{\"data\":[20,21,22,23,24],\"meta\":{\"page\":3,\"per_page\":10,\"total\":25,\"total_pages\":3}}", BunnyKit::Json.encode(page.to_h)
end

def test_pagination_clamps
  items = List(Object).new
  p = BunnyApi::Page.from(Bunny::Conn.new("GET", "/?page=-4&per_page=9999"), items)
  assert_equal 1, p.page
  assert_equal 100, p.per_page
end

def test_cors_preflight
  cors = BunnyApi::Cors.new("https://app.test")
  c = Bunny::Conn.new("OPTIONS", "/api/x")
  c.req_headers["origin"] = "https://app.test"
  r = cors.run(c)
  assert r.halted, "preflight answered"
  assert_equal 204, r.status
  assert_equal "https://app.test", r.resp_headers["access-control-allow-origin"]
  other = Bunny::Conn.new("GET", "/api/x")
  other.req_headers["origin"] = "https://evil.test"
  assert !cors.run(other).resp_headers.has_key?("access-control-allow-origin"), "origin not allowed"
end

def test_bearer_auth
  auth = BunnyApi::BearerAuth.new(->(t : String) { t == "secret" ? "user-1" : "" })
  ok = Bunny::Conn.new("GET", "/")
  ok.req_headers["authorization"] = "Bearer secret"
  r = auth.run(ok)
  assert !r.halted, "authorized"
  assert_equal "user-1", r.assigns["current_user"].to_s
  bad = auth.run(Bunny::Conn.new("GET", "/"))
  assert bad.halted, "rejected"
  assert_equal 401, bad.status
  assert_equal "Bearer", bad.resp_headers["www-authenticate"]
end
