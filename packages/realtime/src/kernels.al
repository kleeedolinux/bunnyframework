# Pure kernels of BunnyLive (no dependencies, so `alice prove` can check them alone).
module BunnyLive
  module Kernels
    # Below this many subscribers a fan-out branch delivers serially.
    pure def self.fan_leaf : Int32
      64
    end

    # Split point of a fan-out range [lo, hi).
    pure def self.fan_mid(lo : Int32, hi : Int32) : Int32
      lo + (hi - lo) / 2
    end

    # Changed dynamic slots between two renders. Index-independent loop: parallel for large views.
    pure def self.changed_slots(borrow last : Array(String), borrow now : Array(String)) : Array(Bool)
      out = Array(Bool).new(now.size)
      for i in 0...now.size
        out[i] = i >= last.size || last[i] != now[i]
      end
      out
    end
  end
end
