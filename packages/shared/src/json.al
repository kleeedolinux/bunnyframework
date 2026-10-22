# JSON: encode Alice/.NET values, decode into Hash/List/scalars.
module BunnyKit
  # JSON null inside decoded collections (collections cannot hold nil).
  class JsonNull
    def to_s : String
      "null"
    end
  end

  module Json
    NULL = JsonNull.new

    def self.encode(v : Object?) : String
      sb = System.Text.StringBuilder.new
      write(sb, v)
      sb.ToString
    end

    def self.write(sb : System.Text.StringBuilder, v : Object?)
      if v == nil || v.is_a?(JsonNull)
        sb.Append("null")
      elsif v.is_a?(String)
        write_string(sb, v.as(String))
      elsif v.is_a?(Bool)
        sb.Append(v.as(Bool) ? "true" : "false")
      elsif v.is_a?(Int32) || v.is_a?(Int64)
        sb.Append(v.to_s)
      elsif v.is_a?(Float64)
        sb.Append(v.as(Float64).ToString("R", System.Globalization.CultureInfo.InvariantCulture))
      elsif v.is_a?(System.Collections.IDictionary)
        sb.Append("{")
        first = true
        d = v.as(System.Collections.IDictionary)
        for k in d.Keys
          sb.Append(",") unless first
          first = false
          write_string(sb, k.to_s)
          sb.Append(":")
          write(sb, d[k])
        end
        sb.Append("}")
      elsif v.is_a?(System.Collections.IEnumerable)
        sb.Append("[")
        first = true
        for item in v.as(System.Collections.IEnumerable)
          sb.Append(",") unless first
          first = false
          write(sb, item)
        end
        sb.Append("]")
      else
        write_string(sb, v.to_s)
      end
    end

    def self.write_string(sb : System.Text.StringBuilder, s : String)
      sb.Append('"')
      for i in 0...s.size
        ch = s[i]
        if ch == '"'
          sb.Append("\\\"")
        elsif ch == '\\'
          sb.Append("\\\\")
        elsif ch == '\n'
          sb.Append("\\n")
        elsif ch == '\r'
          sb.Append("\\r")
        elsif ch == '\t'
          sb.Append("\\t")
        elsif ch.to_i < 32
          sb.Append("\\u")
          sb.Append(ch.to_i.ToString("x4"))
        else
          sb.Append(ch)
        end
      end
      sb.Append('"')
    end

    def self.decode(text : String) : Object?
      doc = System.Text.Json.JsonDocument.Parse(text)
      convert(doc.RootElement)
    end

    def self.convert(e : System.Text.Json.JsonElement) : Object?
      kind = e.ValueKind
      if kind == System.Text.Json.JsonValueKind.Object
        h = Hash(String, Object).new
        for p in e.EnumerateObject
          h[p.Name] = convert(p.Value) || NULL
        end
        h
      elsif kind == System.Text.Json.JsonValueKind.Array
        l = List(Object).new
        for item in e.EnumerateArray
          l << (convert(item) || NULL)
        end
        l
      elsif kind == System.Text.Json.JsonValueKind.String
        e.GetString
      elsif kind == System.Text.Json.JsonValueKind.Number
        n = 0_i64
        if e.TryGetInt64(out n)
          n
        else
          e.GetDouble
        end
      elsif kind == System.Text.Json.JsonValueKind.True
        true
      elsif kind == System.Text.Json.JsonValueKind.False
        false
      else
        nil
      end
    end
  end
end
