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

    # Pure-Alice recursive-descent decoder. null decodes to Json::NULL.
    def self.decode(text : String) : Object
      r = JsonReader.new(text)
      v = r.read_value
      r.skip_ws
      r.fail("trailing characters") if r.pos < text.size
      v
    end
  end

  class JsonReader
    getter pos : Int32 = 0

    def initialize(@s : String)
    end

    def fail(msg : String)
      raise System.FormatException.new("invalid JSON at #{@pos}: #{msg}")
    end

    def skip_ws
      while @pos < @s.size
        ch = @s[@pos]
        break unless ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t'
        @pos += 1
      end
    end

    def peek : Char
      fail("unexpected end") if @pos >= @s.size
      @s[@pos]
    end

    def expect(ch : Char)
      fail("expected #{ch}") unless peek == ch
      @pos += 1
    end

    def literal(word : String)
      fail("expected #{word}") unless @pos + word.size <= @s.size && @s.Substring(@pos, word.size) == word
      @pos += word.size
    end

    def read_value : Object
      skip_ws
      ch = peek
      if ch == '{'
        read_object
      elsif ch == '['
        read_array
      elsif ch == '"'
        read_string
      elsif ch == 't'
        literal("true")
        true
      elsif ch == 'f'
        literal("false")
        false
      elsif ch == 'n'
        literal("null")
        Json::NULL
      else
        read_number
      end
    end

    def read_object : Object
      h = Hash(String, Object).new
      expect('{')
      skip_ws
      if peek == '}'
        @pos += 1
        return h
      end
      while true
        skip_ws
        key = read_string
        skip_ws
        expect(':')
        h[key] = read_value
        skip_ws
        if peek == ','
          @pos += 1
        else
          expect('}')
          return h
        end
      end
      h
    end

    def read_array : Object
      l = List(Object).new
      expect('[')
      skip_ws
      if peek == ']'
        @pos += 1
        return l
      end
      while true
        l << read_value
        skip_ws
        if peek == ','
          @pos += 1
        else
          expect(']')
          return l
        end
      end
      l
    end

    def read_string : String
      expect('"')
      sb = System.Text.StringBuilder.new
      while true
        ch = peek
        @pos += 1
        if ch == '"'
          return sb.ToString
        elsif ch == '\\'
          e = peek
          @pos += 1
          if e == 'n'
            sb.Append('\n')
          elsif e == 't'
            sb.Append('\t')
          elsif e == 'r'
            sb.Append('\r')
          elsif e == 'b'
            sb.Append('\b')
          elsif e == 'f'
            sb.Append('\f')
          elsif e == 'u'
            fail("bad unicode escape") if @pos + 4 > @s.size
            code = 0
            for k in 0...4
              code = code * 16 + hex(@s[@pos + k])
            end
            @pos += 4
            sb.Append(code.chr)
          else
            sb.Append(e)
          end
        else
          sb.Append(ch)
        end
      end
      ""
    end

    def hex(ch : Char) : Int32
      return ch.to_i - 48 if ch >= '0' && ch <= '9'
      return ch.to_i - 87 if ch >= 'a' && ch <= 'f'
      return ch.to_i - 55 if ch >= 'A' && ch <= 'F'
      fail("bad hex digit")
      0
    end

    def read_number : Object
      start = @pos
      is_float = false
      @pos += 1 if peek == '-'
      while @pos < @s.size
        ch = @s[@pos]
        if ch >= '0' && ch <= '9'
          @pos += 1
        elsif ch == '.' || ch == 'e' || ch == 'E' || ch == '+' || ch == '-'
          is_float = true
          @pos += 1
        else
          break
        end
      end
      fail("expected value") if @pos == start
      text = @s.Substring(start, @pos - start)
      if is_float
        Float64.Parse(text, System.Globalization.CultureInfo.InvariantCulture)
      else
        Int64.Parse(text)
      end
    end
  end
end
