# Router: compiled segment tree, scopes and pipelines.

def hello(c : Bunny::Conn) : Bunny::Conn
  c.text("hello")
end

def build_router : Bunny::Router
  r = Bunny::Router.new
  r.pipeline("api") do |p|
    p.plug(->(c : Bunny::Conn) { c.put_resp_header("x-pipe", "api") })
  end
  r.pipeline("auth") do |p|
    p.plug(->(c : Bunny::Conn) { c.req_headers.has_key?("authorization") ? c : c.put_status(401).text("no").halt })
  end
  r.get("/", ->(c : Bunny::Conn) { hello(c) })
  r.get("/posts/:id", ->(c : Bunny::Conn) { c.text("post #{c.param("id")}") })
  r.post("/posts", ->(c : Bunny::Conn) { c.put_status(201).text("made #{c.param("title")}") })
  r.get("/files/*path", ->(c : Bunny::Conn) { c.text(c.param("path")) })
  r.scope("/api", ["api"]) do |s|
    s.get("/ping", ->(c : Bunny::Conn) { c.text("pong") })
    s.scope("/admin", ["auth"]) do |a|
      a.get("/stats", ->(c : Bunny::Conn) { c.text("stats") })
    end
  end
  r
end

def test_static_root
  c = build_router.dispatch(Bunny::Conn.new("GET", "/"))
  assert_equal 200, c.status
  assert_equal "hello", c.resp_body
end

def test_path_params
  c = build_router.dispatch(Bunny::Conn.new("GET", "/posts/42"))
  assert_equal "post 42", c.resp_body
  assert_equal "42", c.path_params["id"]
end

def test_wildcard
  c = build_router.dispatch(Bunny::Conn.new("GET", "/files/a/b/c.txt"))
  assert_equal "a/b/c.txt", c.resp_body
end

def test_method_dispatch_and_405
  r = build_router
  assert_equal 201, r.dispatch(Bunny::Conn.new("POST", "/posts?title=x")).status
  c = r.dispatch(Bunny::Conn.new("DELETE", "/posts"))
  assert_equal 405, c.status
end

def test_404
  assert_equal 404, build_router.dispatch(Bunny::Conn.new("GET", "/nope")).status
end

def test_scope_runs_pipeline
  c = build_router.dispatch(Bunny::Conn.new("GET", "/api/ping"))
  assert_equal "pong", c.resp_body
  assert_equal "api", c.resp_headers["x-pipe"]
end

def test_nested_scope_halts
  r = build_router
  c = r.dispatch(Bunny::Conn.new("GET", "/api/admin/stats"))
  assert_equal 401, c.status
  assert_equal "api", c.resp_headers["x-pipe"]
  ok = Bunny::Conn.new("GET", "/api/admin/stats")
  ok.req_headers["authorization"] = "t"
  assert_equal "stats", r.dispatch(ok).resp_body
end

def test_route_table
  rows = build_router.routes
  assert rows.any? { |row| row == "GET /api/admin/stats" }, "lists nested route"
  assert_equal 6, rows.size
end
