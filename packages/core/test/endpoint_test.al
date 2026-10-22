# Endpoint: plugs before the router, error handling, built-in plugs.

def endpoint_router : Bunny::Router
  r = Bunny::Router.new
  r.get("/", ->(c : Bunny::Conn) { c.text("home") })
  r.get("/boom", ->(c : Bunny::Conn) { raise System.InvalidOperationException.new("kaput") })
  r.put("/items/:id", ->(c : Bunny::Conn) { c.text("put #{c.param("id")}") })
  r
end

def test_endpoint_runs_plugs_then_router
  e = Bunny::Endpoint.new(endpoint_router)
  e.plug(Bunny::Plugs::RequestId.new)
  e.plug(Bunny::Plugs::SecureHeaders.new)
  c = e.run(Bunny::Conn.new("GET", "/"))
  assert_equal "home", c.resp_body
  assert c.resp_headers["x-request-id"].size >= 16, "request id"
  assert_equal "nosniff", c.resp_headers["x-content-type-options"]
end

def test_endpoint_rescues_errors
  e = Bunny::Endpoint.new(endpoint_router)
  c = e.run(Bunny::Conn.new("GET", "/boom"))
  assert_equal 500, c.status
  assert c.resp_body.Contains("Internal Server Error"), c.resp_body
  e.debug = true
  d = e.run(Bunny::Conn.new("GET", "/boom"))
  assert d.resp_body.Contains("kaput"), d.resp_body
end

def test_method_override
  e = Bunny::Endpoint.new(endpoint_router)
  e.plug(Bunny::Plugs::MethodOverride.new)
  c = Bunny::Conn.new("POST", "/items/7")
  c.req_headers["content-type"] = "application/x-www-form-urlencoded"
  c.body = "_method=PUT"
  assert_equal "put 7", e.run(c).resp_body
end

def test_head_drops_body
  e = Bunny::Endpoint.new(endpoint_router)
  e.plug(Bunny::Plugs::Head.new)
  c = e.run(Bunny::Conn.new("HEAD", "/"))
  assert_equal 200, c.status
  assert_equal "", c.resp_body
end

def test_static_files
  dir = System.IO.Path.Combine(System.IO.Path.GetTempPath, "bunny-static-#{System.Guid.NewGuid}")
  System.IO.Directory.CreateDirectory(dir)
  System.IO.File.WriteAllText(System.IO.Path.Combine(dir, "app.css"), "body{}")
  e = Bunny::Endpoint.new(endpoint_router)
  e.plug(Bunny::Plugs::Static.new("/assets", dir))
  c = e.run(Bunny::Conn.new("GET", "/assets/app.css"))
  assert_equal "body{}", c.resp_body
  assert_equal "text/css; charset=utf-8", c.resp_headers["content-type"]
  assert c.halted, "static halts"
  t = e.run(Bunny::Conn.new("GET", "/assets/../secret"))
  assert_equal 404, t.status
  System.IO.Directory.Delete(dir, true)
end

def test_cookies
  c = Bunny::Conn.new("GET", "/")
  c.req_headers["cookie"] = "a=1; b=two"
  assert_equal "two", c.cookies["b"]
  c.put_resp_cookie("s", "v")
  assert_equal "s=v; Path=/; HttpOnly; SameSite=Lax", c.resp_cookies[0]
end
