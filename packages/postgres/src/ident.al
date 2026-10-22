# SQL identifier validation: only [a-z_][a-z0-9_]{0,62} reaches SQL text. Pure kernel.
module BunnyPg
  module Ident
    pure def self.valid_char?(ch : Char, first : Bool) : Bool
      return true if ch >= 'a' && ch <= 'z'
      return true if ch == '_'
      !first && ch >= '0' && ch <= '9'
    end

    pure def self.valid?(s : String) : Bool
      return false if s.size == 0 || s.size > 63
      for i in 0...s.size
        return false unless valid_char?(s[i], i == 0)
      end
      true
    end

    def self.check(s : String) : String
      raise System.ArgumentException.new("unsafe SQL identifier: " + s) unless valid?(s)
      "\"" + s + "\""
    end
  end
end
