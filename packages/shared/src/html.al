# HTML escaping for untrusted text.
# `entity` is the pure kernel proven in RULES.al; `escape` is the fast StringBuilder path over it.
module BunnyKit
  module Html
    pure def self.entity(ch : Char) : String
      return "&lt;" if ch == '<'
      return "&gt;" if ch == '>'
      return "&amp;" if ch == '&'
      return "&quot;" if ch == '"'
      return "&#39;" if ch == '\''
      ""
    end

    pure def self.special?(ch : Char) : Bool
      ch == '<' || ch == '>' || ch == '&' || ch == '"' || ch == '\''
    end

    def self.escape(s : String) : String
      return s unless needs_escape?(s)
      sb = System.Text.StringBuilder.new(s.size + 16)
      for i in 0...s.size
        ch = s[i]
        if special?(ch)
          sb.Append(entity(ch))
        else
          sb.Append(ch)
        end
      end
      sb.ToString
    end

    pure def self.needs_escape?(s : String) : Bool
      for i in 0...s.size
        return true if special?(s[i])
      end
      false
    end
  end
end
