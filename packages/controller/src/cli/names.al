# Inflections and field specs for generators.
module BunnyCli
  class Field
    getter name : String
    getter kind : String

    def initialize(@name : String, @kind : String)
    end
  end

  module Names
    def self.snake(s : String) : String
      sb = System.Text.StringBuilder.new
      for i in 0...s.size
        ch = s[i]
        if System.Char.IsUpper(ch)
          sb.Append('_') if i > 0 && s[i - 1] != '_'
          sb.Append(System.Char.ToLowerInvariant(ch))
        else
          sb.Append(ch)
        end
      end
      sb.ToString
    end

    def self.camel(s : String) : String
      sb = System.Text.StringBuilder.new
      up = true
      for i in 0...s.size
        ch = s[i]
        if ch == '_' || ch == '-'
          up = true
        elsif up
          sb.Append(System.Char.ToUpperInvariant(ch))
          up = false
        else
          sb.Append(ch)
        end
      end
      sb.ToString
    end

    def self.plural(s : String) : String
      return s + "es" if s.EndsWith("s") || s.EndsWith("x") || s.EndsWith("z") || s.EndsWith("ch") || s.EndsWith("sh")
      if s.EndsWith("y") && s.size > 1 && "aeiou".IndexOf(s[s.size - 2]) < 0
        return s.Substring(0, s.size - 1) + "ies"
      end
      s + "s"
    end

    def self.fields(specs : Array(String)) : List(Field)
      out = List(Field).new
      for spec in specs
        colon = spec.IndexOf(":")
        if colon < 0
          out << Field.new(spec, "string")
        else
          out << Field.new(spec.Substring(0, colon), spec.Substring(colon + 1))
        end
      end
      out
    end
  end
end
