# Security primitives: constant-time comparison (pure, proven in RULES.al), tokens, signing.
module Bunny
  module Secure
    # Constant-time for equal lengths: no early exit on the first differing char.
    pure def self.equal?(a : String, b : String) : Bool
      diff = a.size ^ b.size
      n = a.size < b.size ? a.size : b.size
      for i in 0...n
        diff = diff | ((a[i] - '\0') ^ (b[i] - '\0'))
      end
      diff == 0
    end

    def self.b64url(bytes : Array(UInt8)) : String
      System.Convert.ToBase64String(bytes).TrimEnd('=').Replace("+", "-").Replace("/", "_")
    end

    def self.from_b64url(s : String) : Array(UInt8)
      t = s.Replace("-", "+").Replace("_", "/")
      pad = (4 - t.size % 4) % 4
      System.Convert.FromBase64String(t + System.String.new('=', pad))
    end

    def self.random_token : String
      b64url(System.Security.Cryptography.RandomNumberGenerator.GetBytes(32))
    end

    def self.sign(secret : String, payload : String) : String
      key = System.Text.Encoding.UTF8.GetBytes(secret)
      b64url(System.Security.Cryptography.HMACSHA256.HashData(key, System.Text.Encoding.UTF8.GetBytes(payload)))
    end
  end
end
