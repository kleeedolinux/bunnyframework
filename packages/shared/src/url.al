# Percent-decoding and query strings.
module BunnyKit
  module Url
    def self.decode(s : String) : String
      System.Uri.UnescapeDataString(s.Replace("+", " "))
    end

    def self.encode(s : String) : String
      System.Uri.EscapeDataString(s)
    end

    def self.parse_query(q : String) : Hash(String, String)
      out = Hash(String, String).new
      return out if q.size == 0
      for pair in q.split("&")
        next if pair.size == 0
        eq = pair.IndexOf("=")
        if eq < 0
          out[decode(pair)] = ""
        else
          out[decode(pair.Substring(0, eq))] = decode(pair.Substring(eq + 1))
        end
      end
      out
    end
  end
end
