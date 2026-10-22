# EAL compiler: .html.eal source -> Alice view class source.
#   <%= expr %>  escaped output     <%== expr %>  raw output
#   <% code %>   Alice code         <%# text %>   comment
#   <%@ name : Type, ... %>  typed assigns, read from the assigns hash
# Top-level output tags and top-level blocks are the dynamic slots; text between them is static.
module Bunny
  class EalToken
    getter kind : String
    getter body : String

    def initialize(@kind : String, @body : String)
    end
  end

  module Eal
    EXT = ".html.eal"

    # Token kinds (input of `plan`).
    pure def self.k_text : Int32
      0
    end
    pure def self.k_out : Int32
      1
    end
    pure def self.k_open : Int32
      2
    end
    pure def self.k_close : Int32
      3
    end
    pure def self.k_mid : Int32
      4
    end
    pure def self.k_code : Int32
      5
    end
    pure def self.k_skip : Int32
      6
    end

    # Actions (output of `plan`). Slot actions open/close a LiveView dynamic slot.
    pure def self.a_static : Int32
      0
    end
    pure def self.a_text : Int32
      1
    end
    pure def self.a_slot_out : Int32
      2
    end
    pure def self.a_out : Int32
      3
    end
    pure def self.a_slot_open : Int32
      4
    end
    pure def self.a_code : Int32
      5
    end
    pure def self.a_slot_close : Int32
      6
    end
    pure def self.a_skip : Int32
      7
    end

    # Verdicts in the last cell of `plan`.
    pure def self.ok : Int32
      0
    end
    pure def self.err_unexpected : Int32
      -1
    end
    pure def self.err_missing_end : Int32
      -2
    end

    # The static/dynamic split as a pure function of token kinds (proven in RULES.al).
    # Returns one action per token plus a final verdict cell.
    pure def self.plan(kinds : Array(Int32)) : Array(Int32)
      n = kinds.size
      out = Array(Int32).new(n + 1)
      depth = 0
      for i in 0...n
        k = kinds[i]
        if k == k_text
          out[i] = depth == 0 ? a_static : a_text
        elsif k == k_out
          out[i] = depth == 0 ? a_slot_out : a_out
        elsif k == k_open
          out[i] = depth == 0 ? a_slot_open : a_code
          depth += 1
        elsif k == k_close
          if depth == 0
            out[n] = err_unexpected
            return out
          end
          depth -= 1
          out[i] = depth == 0 ? a_slot_close : a_code
        elsif k == k_mid
          if depth == 0
            out[n] = err_unexpected
            return out
          end
          out[i] = a_code
        elsif k == k_code
          out[i] = a_code
        else
          out[i] = a_skip
        end
      end
      out[n] = depth == 0 ? ok : err_missing_end
      out
    end

    def self.kind_of(t : EalToken) : Int32
      k = t.kind
      return k_text if k == "text"
      return k_out if k == "esc" || k == "raw"
      return k_skip if k == "decl"
      code = t.body
      return k_close if closes_block?(code)
      return k_open if opens_block?(code)
      return k_mid if code.StartsWith("else") || code.StartsWith("elsif") || code.StartsWith("when") || code.StartsWith("rescue") || code.StartsWith("ensure")
      k_code
    end

    def self.class_name(name : String) : String
      sb = System.Text.StringBuilder.new
      upper = true
      for i in 0...name.size
        ch = name[i]
        if ch == '/' || ch == '_' || ch == '-' || ch == '.'
          upper = true
        elsif upper
          sb.Append(System.Char.ToUpperInvariant(ch))
          upper = false
        else
          sb.Append(ch)
        end
      end
      sb.Append("View")
      sb.ToString
    end

    # "templates/posts/show.html.eal" under root "templates" -> "posts/show"
    def self.template_name(root : String, file : String) : String
      rel = file.Replace("\\", "/")
      r = root.Replace("\\", "/").TrimEnd('/') + "/"
      rel = rel.Substring(r.size) if rel.StartsWith(r)
      rel = rel.Substring(0, rel.size - EXT.size) if rel.EndsWith(EXT)
      rel
    end

    def self.tokenize(src : String) : List(EalToken)
      out = List(EalToken).new
      pos = 0
      while pos < src.size
        open = src.IndexOf("<%", pos)
        if open < 0
          out << EalToken.new("text", src.Substring(pos))
          break
        end
        out << EalToken.new("text", src.Substring(pos, open - pos)) if open > pos
        close = src.IndexOf("%>", open + 2)
        raise System.FormatException.new("unclosed <% at #{open}") if close < 0
        inner = src.Substring(open + 2, close - open - 2)
        pos = close + 2
        if inner.StartsWith("==")
          out << EalToken.new("raw", inner.Substring(2).Trim)
        elsif inner.StartsWith("=")
          out << EalToken.new("esc", inner.Substring(1).Trim)
        elsif inner.StartsWith("#")
          # comment
        elsif inner.StartsWith("@")
          out << EalToken.new("decl", inner.Substring(1).Trim)
        else
          out << EalToken.new("code", inner.Trim)
        end
      end
      out
    end

    def self.opens_block?(code : String) : Bool
      first = code
      sp = code.IndexOf(" ")
      first = code.Substring(0, sp) if sp >= 0
      return true if first == "if" || first == "unless" || first == "for" || first == "while" || first == "until" || first == "case" || first == "begin"
      return true if code.EndsWith(" do") || code == "do"
      bar = code.LastIndexOf(" do |")
      bar >= 0 && code.EndsWith("|")
    end

    def self.closes_block?(code : String) : Bool
      code == "end" || code.StartsWith("end ") || code.StartsWith("end.")
    end

    # Split "a : T, b : Hash(K, V)" at top-level commas.
    def self.split_decls(s : String) : List(String)
      out = List(String).new
      depth = 0
      start = 0
      for i in 0...s.size
        ch = s[i]
        if ch == '('
          depth += 1
        elsif ch == ')'
          depth -= 1
        elsif ch == ',' && depth == 0
          out << s.Substring(start, i - start).Trim
          start = i + 1
        end
      end
      last = s.Substring(start).Trim
      out << last if last.size > 0
      out
    end

    def self.literal(s : String) : String
      sb = System.Text.StringBuilder.new
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
        elsif ch == '#' && i + 1 < s.size && s[i + 1] == '{'
          sb.Append("\\#")
        else
          sb.Append(ch)
        end
      end
      sb.Append('"')
      sb.ToString
    end

    def self.statics(src : String) : List(String)
      gen = EalGen.new("x", src)
      gen.run
      gen.statics
    end

    def self.compile(name : String, src : String) : String
      gen = EalGen.new(name, src)
      gen.run
      gen.source
    end
  end

  class EalGen
    getter statics : List(String) = List(String).new
    @decls : List(String) = List(String).new
    @body : List(String) = List(String).new
    @pending : System.Text.StringBuilder = System.Text.StringBuilder.new
    @depth : Int32 = 0

    def initialize(@name : String, @src : String)
    end

    def line(s : String) : Nil
      pad = System.String.new(' ', 4 + @depth * 2)
      @body << pad + s
    end

    def flush_static : Nil
      line("out.static(#{@statics.size})")
      @statics << @pending.ToString
      @pending.Clear
    end

    def run : Nil
      tokens = Eal.tokenize(@src)
      kinds = Array(Int32).new(tokens.size)
      for i in 0...tokens.size
        kinds[i] = Eal.kind_of(tokens[i])
      end
      actions = Eal.plan(kinds)
      verdict = actions[tokens.size]
      raise System.FormatException.new("unexpected end/else in #{@name}") if verdict == Eal.err_unexpected
      raise System.FormatException.new("missing end in #{@name}") if verdict == Eal.err_missing_end
      for i in 0...tokens.size
        t = tokens[i]
        a = actions[i]
        if a == Eal.a_static
          @pending.Append(t.body)
        elsif a == Eal.a_text
          line("out.text(#{Eal.literal(t.body)})")
        elsif a == Eal.a_slot_out
          flush_static
          line("out.open_dyn")
          line("out.#{t.kind}(#{t.body})")
          line("out.close_dyn")
        elsif a == Eal.a_out
          line("out.#{t.kind}(#{t.body})")
        elsif a == Eal.a_slot_open
          flush_static
          line("out.open_dyn")
          line(t.body)
          @depth += 1
        elsif a == Eal.a_slot_close
          @depth -= 1
          line(t.body)
          line("out.close_dyn")
        elsif a == Eal.a_code
          k = kinds[i]
          if k == Eal.k_open
            line(t.body)
            @depth += 1
          elsif k == Eal.k_close
            @depth -= 1
            line(t.body)
          elsif k == Eal.k_mid
            @depth -= 1
            line(t.body)
            @depth += 1
          else
            line(t.body)
          end
        elsif t.kind == "decl"
          declare(t.body)
        end
      end
      line("out.static(#{@statics.size})")
      @statics << @pending.ToString
      @pending.Clear
    end

    def declare(body : String) : Nil
      for d in Eal.split_decls(body)
        colon = d.IndexOf(":")
        raise System.FormatException.new("assign needs a type: #{d}") if colon < 0
        var = d.Substring(0, colon).Trim
        ty = d.Substring(colon + 1).Trim
        @decls << "    #{var} = Bunny::View.fetch(a, #{Eal.literal(var)}, #{Eal.literal(@name)}).as(#{ty})"
      end
    end

    def source : String
      sb = System.Text.StringBuilder.new
      sb.Append("# Generated by `bunny compile` from #{@name}#{Eal::EXT}. Do not edit.\n")
      sb.Append("class #{Eal.class_name(@name)} < Bunny::View\n")
      sb.Append("  def initialize\n")
      parts = List(String).new
      for s in @statics
        parts << Eal.literal(s)
      end
      sb.Append("    super(#{Eal.literal(@name)}, [#{String.Join(", ", parts)}])\n")
      sb.Append("  end\n\n")
      sb.Append("  def write(a : Hash(String, Object), out : Bunny::EalOut) : Nil\n")
      for d in @decls
        sb.Append(d).Append('\n')
      end
      for l in @body
        sb.Append(l).Append('\n')
      end
      sb.Append("  end\nend\n")
      sb.ToString
    end
  end
end
