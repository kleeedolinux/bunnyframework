# prove-with: src/ident.al
# BunnyPg invariants, proven by exhaustion (`bunny prove`).

pure def ident_char?(ch : Char) : Bool
  (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') || ch == '_'
end

# For every UTF-16 char in every position: an identifier is accepted only if made of [a-z0-9_]
# and not starting with a digit. So quotes, spaces, semicolons and comments never reach SQL text.
rule ident_accepts_only_safe_chars(c in 0..65535, pos in 0..2)
ch = c.as(Char)
s = pos == 0 ? "" + ch + "ab" : (pos == 1 ? "a" + ch + "b" : "ab" + ch)
ok = BunnyPg::Ident.valid?(s)
expected = ident_char?(ch) && !(pos == 0 && ch >= '0' && ch <= '9')
ok == expected
end

# Length bounds: empty and over-63-char names are rejected (PostgreSQL truncates at 63).
rule ident_length_bounds(n in 0..80)
s = ""
for i in 0...n
  s = s + "a"
end
BunnyPg::Ident.valid?(s) == (n >= 1 && n <= 63)
end
