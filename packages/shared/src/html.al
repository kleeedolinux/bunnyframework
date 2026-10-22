# HTML escaping for untrusted text.
module BunnyKit
  module Html
    def self.escape(s : String) : String
      return s unless needs_escape?(s)
      sb = System.Text.StringBuilder.new(s.size + 16)
      for i in 0...s.size
        ch = s[i]
        if ch == '<'
          sb.Append("&lt;")
        elsif ch == '>'
          sb.Append("&gt;")
        elsif ch == '&'
          sb.Append("&amp;")
        elsif ch == '"'
          sb.Append("&quot;")
        elsif ch == '\''
          sb.Append("&#39;")
        else
          sb.Append(ch)
        end
      end
      sb.ToString
    end

    def self.needs_escape?(s : String) : Bool
      for i in 0...s.size
        ch = s[i]
        return true if ch == '<' || ch == '>' || ch == '&' || ch == '"' || ch == '\''
      end
      false
    end
  end
end
