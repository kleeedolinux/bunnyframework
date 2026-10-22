# Endpoint: the top of the Bunny Hole. Plugs run in order, then the router; errors become 500s.
module Bunny
  class Endpoint < Plug
    getter router : Router
    getter plugs : Pipeline = Pipeline.new
    property debug : Bool = false

    def initialize(@router : Router)
    end

    def plug(p : Plug) : Endpoint
      @plugs.plug(p)
      self
    end

    def plug(f : Func(Conn, Conn)) : Endpoint
      @plugs.plug(f)
      self
    end

    def run(c : Conn) : Conn
      begin
        c = @plugs.run(c)
        c = @router.dispatch(c) unless c.halted
        c.resp_body = "" if c.assigns.has_key?("__head")
        Endpoint.finish(c)
      rescue e : System.Exception
        msg = @debug ? "Internal Server Error\n\n#{e}" : "Internal Server Error"
        Endpoint.finish(c.put_status(500).text(msg))
      end
    end

    def self.finish(c : Conn) : Conn
      i = c.before_send.size - 1
      while i >= 0
        c = c.before_send[i].Invoke(c)
        i -= 1
      end
      c
    end
  end
end
