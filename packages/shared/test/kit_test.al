# BunnyKit: wire-level primitives shared by every package.

def test_reason_phrases
  assert_equal "OK", BunnyKit::Http.reason(200)
  assert_equal "Not Found", BunnyKit::Http.reason(404)
  assert_equal "Unknown", BunnyKit::Http.reason(799)
end

def test_mime_from_extension
  assert_equal "text/html; charset=utf-8", BunnyKit::Mime.for_path("a/index.html")
  assert_equal "application/javascript", BunnyKit::Mime.for_path("app.js")
  assert_equal "application/octet-stream", BunnyKit::Mime.for_path("blob")
end

def test_html_escape
  assert_equal "&lt;a href=&quot;x&quot;&gt;&amp;&#39;", BunnyKit::Html.escape("<a href=\"x\">&'")
  assert_equal "plain", BunnyKit::Html.escape("plain")
end

def test_url_decode
  assert_equal "a b/c", BunnyKit::Url.decode("a+b%2Fc")
  assert_equal "olá", BunnyKit::Url.decode("ol%C3%A1")
end

def test_query_parse
  q = BunnyKit::Url.parse_query("a=1&b=two+words&empty=&flag")
  assert_equal "1", q["a"]
  assert_equal "two words", q["b"]
  assert_equal "", q["empty"]
  assert_equal "", q["flag"]
  assert_equal 4, q.size
end

def test_json_encode_scalars
  assert_equal "\"a\\\"b\\n\"", BunnyKit::Json.encode("a\"b\n")
  assert_equal "42", BunnyKit::Json.encode(42)
  assert_equal "true", BunnyKit::Json.encode(true)
  assert_equal "null", BunnyKit::Json.encode(nil)
end

def test_json_encode_collections
  h = Hash(String, Object).new
  h["n"] = 1
  l = List(Object).new
  l << "x"
  l << 2
  h["l"] = l
  assert_equal "{\"n\":1,\"l\":[\"x\",2]}", BunnyKit::Json.encode(h)
end

def test_json_decode_roundtrip
  v = BunnyKit::Json.decode("{\"a\":[1,\"b\",null,true],\"c\":{\"d\":2.5}}")
  assert_equal "{\"a\":[1,\"b\",null,true],\"c\":{\"d\":2.5}}", BunnyKit::Json.encode(v)
end

def test_json_decode_escapes_and_numbers
  v = BunnyKit::Json.decode(" [\"\\u00e9\\n\", -1.5e2, 0] ")
  assert_equal "[\"é\\n\",-150,0]", BunnyKit::Json.encode(v)
end

def test_json_decode_rejects_garbage
  raised = false
  begin
    BunnyKit::Json.decode("{\"a\":1,}")
  rescue e : System.FormatException
    raised = true
  end
  assert raised, "trailing comma is invalid"
end
