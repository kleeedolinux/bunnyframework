# Session and CSRF plugs. The session is a signed cookie: b64url(json) "." b64url(hmac-sha256).
module Bunny
  module Plugs
    class Session < Plug
      COOKIE = "_bunny_session"

      def initialize(@secret : String)
        raise System.ArgumentException.new("session secret must be at least 32 chars") if @secret.size < 32
      end

      def run(c : Conn) : Conn
        load(c, c.cookies.fetch(COOKIE, ""))
        flashes = List(String).new
        for k in c.session.Keys
          flashes << k if k.StartsWith(Conn::FLASH_PREFIX)
        end
        for k in flashes
          c.flash_in[k.Substring(Conn::FLASH_PREFIX.size)] = c.session[k]
          c.delete_session(k)
        end
        c.register_before_send(->(x : Conn) { store(x) })
      end

      def load(c : Conn, raw : String) : Nil
        dot = raw.IndexOf(".")
        return if dot <= 0
        payload = raw.Substring(0, dot)
        return unless Secure.equal?(Secure.sign(@secret, payload), raw.Substring(dot + 1))
        begin
          v = BunnyKit::Json.decode(System.Text.Encoding.UTF8.GetString(Secure.from_b64url(payload)))
          if v.is_a?(Hash(String, Object))
            v.as(Hash(String, Object)).each { |k, x| c.session[k] = x.to_s }
          end
        rescue e : System.FormatException
        end
      end

      def store(c : Conn) : Conn
        return c unless c.session_changed
        payload = Secure.b64url(System.Text.Encoding.UTF8.GetBytes(BunnyKit::Json.encode(c.session)))
        c.put_resp_cookie(COOKIE, payload + "." + Secure.sign(@secret, payload), "Path=/; HttpOnly; SameSite=Lax")
      end
    end

    # Rejects state-changing requests without the session's token (form field or x-csrf-token).
    class Csrf < Plug
      def run(c : Conn) : Conn
        m = c.method
        return c if m == "GET" || m == "HEAD" || m == "OPTIONS"
        expected = c.get_session(Conn::CSRF_KEY)
        given = c.req_header("x-csrf-token")
        given = c.param(Conn::CSRF_KEY) if given.size == 0
        return c if expected.size > 0 && Secure.equal?(expected, given)
        c.put_status(403).text("Forbidden: invalid CSRF token").halt
      end
    end
  end
end
