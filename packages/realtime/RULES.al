# prove-with: src/kernels.al
# BunnyLive invariants, proven by exhaustion (`alice prove RULES.al src/kernels.al`).

# The fork/join fan-out (same recursion as PubSub.fan_out): number of subscribers reached.
pure def reached(lo : Int32, hi : Int32) : Int32
  return hi - lo if hi - lo <= BunnyLive::Kernels.fan_leaf
  mid = BunnyLive::Kernels.fan_mid(lo, hi)
  reached(lo, mid) + reached(mid, hi)
end

# Every split makes progress: both halves are non-empty and strictly smaller.
rule fan_split_progresses(lo in 0..200, len in 65..5000)
hi = lo + len
mid = BunnyLive::Kernels.fan_mid(lo, hi)
mid > lo && mid < hi
end

# Fan-out reaches every subscriber exactly once, for every list size up to 100k.
rule fan_out_reaches_everyone(n in 0..100000)
reached(0, n) == n
end

pure def word(d : Int32) : String
  return "a" if d == 0
  return "b" if d == 1
  "c"
end

# Render number x (base 3, n slots) -> dynamic slot values.
pure def render_of(x : Int32, n : Int32) : Array(String)
  r = Array(String).new(n)
  v = x
  for i in 0...n
    r[i] = word(v % 3)
    v = v / 3
  end
  r
end

# For every pair of renders with 0..4 slots: applying the diff (changed slots only) to the previous
# render rebuilds the new render exactly -- what bunny.js does on the client.
rule live_diff_rebuilds_render(la in 0..4, lb in 0..4, xa in 0...81, xb in 0...81)
last = render_of(xa, la)
now = render_of(xb, lb)
changed = BunnyLive::Kernels.changed_slots(last, now)
for i in 0...lb
  if changed[i]
    next
  end
  return false if i >= la || last[i] != now[i]
end
for i in 0...lb
  return false if !changed[i] && last[i] != now[i]
end
true
end

# Identical renders produce an empty diff (no traffic when nothing changed).
rule live_diff_empty_when_unchanged(l in 0..4, x in 0...81)
r = render_of(x, l)
changed = BunnyLive::Kernels.changed_slots(r, render_of(x, l))
for i in 0...l
  return false if changed[i]
end
true
end
