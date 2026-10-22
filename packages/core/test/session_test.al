# Signed-cookie sessions, flash and CSRF.

def secret : String
  "test-secret-key-at-least-32-bytes-long!!"
end

def session_endpoint : Bunny::Endpoint
  r = Bunny::Router.new
  r.get("/set", ->(c : Bunny::Conn) { c.put_session("user", "ana").put_flash("info", "saved").text("ok") })
  r.get("/read", ->(c : Bunny::Conn) { c.text(c.get_session("user") + "|" + c.flash("info")) })
  r.get("/token", ->(c : Bunny::Conn) { c.text(c.csrf_token) })
  r.post("/form", ->(c : Bunny::Conn) { c.text("posted") })
  e = Bunny::Endpoint.new(r)
  e.plug(Bunny::Plugs::Session.new(secret))
  e.plug(Bunny::Plugs::Csrf.new)
  e
end

# Carries the response cookie into the next request, like a browser.
def follow(prev : Bunny::Conn, method : String, path : String) : Bunny::Conn
  c = Bunny::Conn.new(method, path)
  for set in prev.resp_cookies
    c.req_headers["cookie"] = set.Substring(0, set.IndexOf(";"))
  end
  c
end

def test_session_roundtrip_and_flash_once
  e = session_endpoint
  a = e.run(Bunny::Conn.new("GET", "/set"))
  assert_equal 1, a.resp_cookies.size
  assert a.resp_cookies[0].StartsWith("_bunny_session="), a.resp_cookies[0]
  assert a.resp_cookies[0].Contains("HttpOnly"), "httponly"
  b = e.run(follow(a, "GET", "/read"))
  assert_equal "ana|saved", b.resp_body
  c = e.run(follow(b, "GET", "/read"))
  assert_equal "ana|", c.resp_body
end

def test_tampered_cookie_is_ignored
  e = session_endpoint
  a = e.run(Bunny::Conn.new("GET", "/set"))
  bad = Bunny::Conn.new("GET", "/read")
  cookie = a.resp_cookies[0].Substring(0, a.resp_cookies[0].IndexOf(";"))
  bad.req_headers["cookie"] = cookie.Substring(0, cookie.size - 2) + "xx"
  assert_equal "|", e.run(bad).resp_body
end

def test_csrf_blocks_post_without_token
  e = session_endpoint
  c = e.run(Bunny::Conn.new("POST", "/form"))
  assert_equal 403, c.status
end

def test_csrf_accepts_form_and_header_token
  e = session_endpoint
  t = e.run(Bunny::Conn.new("GET", "/token"))
  token = t.resp_body
  assert token.size >= 32, token
  form = follow(t, "POST", "/form")
  form.req_headers["content-type"] = "application/x-www-form-urlencoded"
  form.body = "_csrf_token=" + BunnyKit::Url.encode(token)
  assert_equal "posted", e.run(form).resp_body
  hdr = follow(t, "POST", "/form")
  hdr.req_headers["x-csrf-token"] = token
  assert_equal "posted", e.run(hdr).resp_body
  wrong = follow(t, "POST", "/form")
  wrong.req_headers["x-csrf-token"] = token + "x"
  assert_equal 403, e.run(wrong).status
end

def test_constant_time_equal
  assert Bunny::Secure.equal?("abc", "abc"), "same"
  assert !Bunny::Secure.equal?("abc", "abd"), "differs"
  assert !Bunny::Secure.equal?("abc", "ab"), "length"
end
