# prove-with: src/http.al src/html.al src/json.al
# BunnyKit invariants, proven by exhaustion (`alice prove`). Kernels are pure; fast paths build on them.

pure def no_raw_html?(s : String) : Bool
  for i in 0...s.size
    ch = s[i]
    return false if ch == '<' || ch == '>' || ch == '"' || ch == '\''
  end
  true
end

# Every status a server can send has a reason phrase; known codes never fall back to "Unknown".
rule every_status_has_a_reason(code in 100..599)
r = BunnyKit::Http.reason(code)
r != "" && (code != 200 || r == "OK") && (code != 404 || r == "Not Found") && (code != 500 || r == "Internal Server Error")
end

# For every UTF-16 code unit: special chars get an entity free of raw HTML chars; others get none.
rule html_entity_is_safe(c in 0..65535)
ch = c.as(Char)
e = BunnyKit::Html.entity(ch)
if BunnyKit::Html.special?(ch)
  e.size > 1 && e[0] == '&' && e[e.size - 1] == ';' && no_raw_html?(e)
else
  e == ""
end
end

# needs_escape? is exact on one-char texts.
rule needs_escape_matches_special(c in 0..65535)
ch = c.as(Char)
BunnyKit::Html.needs_escape?("x" + ch) == BunnyKit::Html.special?(ch)
end

# JSON string escaping round-trips every UTF-16 code unit through the decoder's kernels.
rule json_escape_roundtrips(c in 0..65535)
ch = c.as(Char)
return true if BunnyKit::Json.plain?(ch)
e = BunnyKit::Json.escape_char(ch)
return false unless e[0] == '\\'
if e.size == 2
  BunnyKit::Json.unescape(e[1]) == ch
else
  e.size == 6 && e[1] == 'u' && (BunnyKit::Json.hex_value(e[2]) * 4096 + BunnyKit::Json.hex_value(e[3]) * 256 + BunnyKit::Json.hex_value(e[4]) * 16 + BunnyKit::Json.hex_value(e[5])) == c
end
end

# Plain chars never need escaping and are never control chars, quotes or backslashes.
rule json_plain_is_safe(c in 0..65535)
ch = c.as(Char)
!BunnyKit::Json.plain?(ch) || (c >= 32 && ch != '"' && ch != '\\')
end

# hex_value accepts exactly [0-9a-fA-F] and maps them to 0..15.
rule hex_value_is_exact(c in 0..65535)
ch = c.as(Char)
v = BunnyKit::Json.hex_value(ch)
is_hex = (ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f') || (ch >= 'A' && ch <= 'F')
is_hex ? (v >= 0 && v <= 15 && BunnyKit::Json.hex_value(BunnyKit::Json.hex_digit(v)) == v) : v == -1
end
