# Plugs and pipelines: ordered Conn -> Conn steps that stop on halt.
module Bunny
  abstract class Plug
    abstract def run(c : Conn) : Conn
  end

  class FnPlug < Plug
    def initialize(@f : Func(Conn, Conn))
    end

    def run(c : Conn) : Conn
      @f.Invoke(c)
    end
  end

  class Pipeline < Plug
    getter plugs : List(Plug) = List(Plug).new

    def plug(p : Plug) : Pipeline
      @plugs << p
      self
    end

    def plug(f : Func(Conn, Conn)) : Pipeline
      @plugs << FnPlug.new(f)
      self
    end

    def run(c : Conn) : Conn
      for p in @plugs
        return c if c.halted
        c = p.run(c)
      end
      c
    end
  end
end
