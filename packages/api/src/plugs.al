# API plugs: CORS and bearer-token auth.
module BunnyApi
  class Cors < Bunny::Plug
    def initialize(@origins : String)
    end

    def allowed?(origin : String) : Bool
      return false if origin.size == 0
      return true if @origins == "*"
      for o in @origins.split(",")
        return true if o.Trim == origin
      end
      false
    end

    def run(c : Bunny::Conn) : Bunny::Conn
      origin = c.req_header("origin")
      return c unless allowed?(origin)
      c.put_resp_header("access-control-allow-origin", origin)
      c.put_resp_header("vary", "origin")
      if c.method == "OPTIONS"
        c.put_resp_header("access-control-allow-methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
        c.put_resp_header("access-control-allow-headers", "authorization, content-type")
        c.put_resp_header("access-control-max-age", "86400")
        return c.send_resp(204, "").halt
      end
      c
    end
  end

  # verify(token) returns the user id, or "" to reject. Sets assigns["current_user"].
  class BearerAuth < Bunny::Plug
    def initialize(@verify : Func(String, String))
    end

    def run(c : Bunny::Conn) : Bunny::Conn
      h = c.req_header("authorization")
      user = ""
      user = @verify.Invoke(h.Substring(7).Trim) if h.StartsWith("Bearer ")
      if user.size == 0
        c.put_resp_header("www-authenticate", "Bearer")
        return Render.error(c, 401, "unauthorized").halt
      end
      c.assign("current_user", user)
    end
  end
end
