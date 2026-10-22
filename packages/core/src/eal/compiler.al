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
      for t in Eal.tokenize(@src)
        k = t.kind
        if k == "text"
          if @depth == 0
            @pending.Append(t.body)
          else
            line("out.text(#{Eal.literal(t.body)})")
          end
        elsif k == "decl"
          for d in Eal.split_decls(t.body)
            colon = d.IndexOf(":")
            raise System.FormatException.new("assign needs a type: #{d}") if colon < 0
            var = d.Substring(0, colon).Trim
            ty = d.Substring(colon + 1).Trim
            @decls << "    #{var} = Bunny::View.fetch(a, #{Eal.literal(var)}, #{Eal.literal(@name)}).as(#{ty})"
          end
        elsif k == "esc" || k == "raw"
          if @depth == 0
            flush_static
            line("out.open_dyn")
            line("out.#{k}(#{t.body})")
            line("out.close_dyn")
          else
            line("out.#{k}(#{t.body})")
          end
        else
          code = t.body
          if Eal.closes_block?(code)
            raise System.FormatException.new("unexpected end in #{@name}") if @depth == 0
            @depth -= 1
            line(code)
            line("out.close_dyn") if @depth == 0
          elsif Eal.opens_block?(code)
            if @depth == 0
              flush_static
              line("out.open_dyn")
            end
            line(code)
            @depth += 1
          elsif code.StartsWith("else") || code.StartsWith("elsif") || code.StartsWith("when") || code.StartsWith("rescue") || code.StartsWith("ensure")
            @depth -= 1
            line(code)
            @depth += 1
          else
            line(code)
          end
        end
      end
      raise System.FormatException.new("missing end in #{@name}") if @depth != 0
      line("out.static(#{@statics.size})")
      @statics << @pending.ToString
      @pending.Clear
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
