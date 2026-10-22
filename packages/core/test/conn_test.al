# Conn: the single value flowing through the Bunny Hole.

def test_conn_parses_path_and_query
  c = Bunny::Conn.new("GET", "/posts/1?page=2&q=a+b")
  assert_equal "/posts/1", c.path
  assert_equal "2", c.query_params["page"]
  assert_equal "a b", c.param("q")
  assert_equal "", c.param("missing")
end

def test_conn_response_helpers
  c = Bunny::Conn.new("GET", "/")
  c.put_status(201).put_resp_header("x-a", "1").text("hi")
  assert_equal 201, c.status
  assert_equal "hi", c.resp_body
  assert_equal "1", c.resp_headers["x-a"]
  assert_equal "text/plain; charset=utf-8", c.resp_headers["content-type"]
end

def test_conn_json_and_redirect
  c = Bunny::Conn.new("GET", "/")
  h = Hash(String, Object).new
  h["ok"] = true
  c.json(h)
  assert_equal "{\"ok\":true}", c.resp_body
  assert_equal "application/json", c.resp_headers["content-type"]
  r = Bunny::Conn.new("GET", "/").redirect("/there")
  assert_equal 302, r.status
  assert_equal "/there", r.resp_headers["location"]
  assert r.halted, "redirect halts"
end

def test_conn_form_body_params
  c = Bunny::Conn.new("POST", "/p")
  c.req_headers["content-type"] = "application/x-www-form-urlencoded"
  c.body = "title=Hi+there&n=3"
  assert_equal "Hi there", c.param("title")
end

def test_conn_json_body_params
  c = Bunny::Conn.new("POST", "/p")
  c.req_headers["content-type"] = "application/json"
  c.body = "{\"title\":\"x\",\"n\":3}"
  assert_equal "x", c.param("title")
  assert_equal "3", c.param("n")
end

def test_assigns
  c = Bunny::Conn.new("GET", "/")
  c.assign("user", "ana")
  assert_equal "ana", c.assigns["user"].to_s
end
