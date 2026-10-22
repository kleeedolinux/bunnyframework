# prove-with: src/eal/compiler.al src/secure.al
# Bunny Hole invariants, proven by exhaustion (`alice prove`).

# Specification of a well-formed template: blocks balance, else/end never appear outside a block.
pure def well_formed?(kinds : Array(Int32)) : Bool
  depth = 0
  for k in kinds
    if k == Bunny::Eal.k_open
      depth += 1
    elsif k == Bunny::Eal.k_close
      return false if depth == 0
      depth -= 1
    elsif k == Bunny::Eal.k_mid
      return false if depth == 0
    end
  end
  depth == 0
end

# Token sequence number x (base 7, n digits) -> kinds.
pure def kinds_of(x : Int32, n : Int32) : Array(Int32)
  ks = Array(Int32).new(n)
  v = x
  for i in 0...n
    ks[i] = v % 7
    v = v / 7
  end
  ks
end

# For EVERY template of 8 tokens: the compiler accepts exactly the well-formed ones, and on those
# dynamic slots open and close strictly alternating, nested output only appears inside a slot, and
# top-level text only outside. So statics == slots + 1 and LiveView diffs index the right slots.
rule eal_static_dynamic_split(x in 0...5764801)
kinds = kinds_of(x, 8)
plan = Bunny::Eal.plan(kinds)
verdict = plan[8]
return verdict != Bunny::Eal.ok unless well_formed?(kinds)
return false unless verdict == Bunny::Eal.ok
in_slot = false
for i in 0...8
  a = plan[i]
  if a == Bunny::Eal.a_slot_out
    return false if in_slot
  elsif a == Bunny::Eal.a_slot_open
    return false if in_slot
    in_slot = true
  elsif a == Bunny::Eal.a_slot_close
    return false unless in_slot
    in_slot = false
  elsif a == Bunny::Eal.a_text || a == Bunny::Eal.a_out
    return false unless in_slot
  elsif a == Bunny::Eal.a_static
    return false if in_slot
  end
end
!in_slot
end

# Every action is one of the defined codes (no unhandled branch in the generator).
rule eal_plan_actions_are_known(x in 0...5764801)
plan = Bunny::Eal.plan(kinds_of(x, 8))
return true unless plan[8] == Bunny::Eal.ok
for i in 0...8
  return false if plan[i] < Bunny::Eal.a_static || plan[i] > Bunny::Eal.a_skip
end
true
end

pure def word_of(x : Int32, n : Int32) : String
  s = ""
  v = x
  for i in 0...n
    s = s + (v % 2 == 0 ? "a" : "b")
    v = v / 2
  end
  s
end

# The constant-time comparison used for CSRF tokens and session signatures agrees with `==`
# on every pair of strings over {a, b} up to length 5.
rule secure_equal_matches_eq(la in 0..5, lb in 0..5, xa in 0...32, xb in 0...32)
a = word_of(xa, la)
b = word_of(xb, lb)
Bunny::Secure.equal?(a, b) == (a == b)
end
