def test_home_page
  EalViews.install
  c = App.router.dispatch(Bunny::Conn.new("GET", "/"))
  assert_equal 200, c.status
  assert c.resp_body.Contains("Welcome to Bunny"), c.resp_body
end

def test_health
  assert_equal "ok", App.router.dispatch(Bunny::Conn.new("GET", "/api/health")).resp_body
end

# A browser form post: the session holds the CSRF token and the form echoes it.
def form_post(path : String, body : String) : Bunny::Conn
  c = Bunny::Conn.new("POST", path)
  c.session["_csrf_token"] = "test-token"
  c.req_headers["content-type"] = "application/x-www-form-urlencoded"
  c.body = body + "&_csrf_token=test-token"
  c
end

def test_post_without_csrf_token_is_forbidden
  c = Bunny::Conn.new("POST", "/posts")
  c.req_headers["content-type"] = "application/x-www-form-urlencoded"
  c.body = "title=x&body=y&views=1"
  assert_equal 403, App.router.dispatch(c).status
end

def test_resource_flow
  EalViews.install
  r = App.router
  bad = r.dispatch(form_post("/posts", "title=&body=x&views=abc"))
  assert_equal 422, bad.status
  assert bad.resp_body.Contains("be blank"), bad.resp_body
  ok = r.dispatch(form_post("/posts", "title=Hello&body=World&views=3"))
  assert_equal 302, ok.status
  show = r.dispatch(Bunny::Conn.new("GET", ok.resp_headers["location"]))
  assert show.resp_body.Contains("Hello"), show.resp_body
  idx = r.dispatch(Bunny::Conn.new("GET", "/posts"))
  assert idx.resp_body.Contains("Hello"), idx.resp_body
  assert_equal 200, r.dispatch(Bunny::Conn.new("GET", "/posts/new")).status
  assert_equal 200, r.dispatch(Bunny::Conn.new("GET", "/admin")).status
end
