# Built-in plugs.
module Bunny
  module Plugs
    class RequestId < Plug
      def run(c : Conn) : Conn
        id = c.req_header("x-request-id")
        id = System.Guid.NewGuid.ToString("N") if id.size == 0
        c.put_resp_header("x-request-id", id)
      end
    end

    class SecureHeaders < Plug
      def run(c : Conn) : Conn
        c.put_resp_header("x-content-type-options", "nosniff")
        c.put_resp_header("x-frame-options", "SAMEORIGIN")
        c.put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
      end
    end

    # POST with _method=PUT|PATCH|DELETE becomes that method (HTML forms).
    class MethodOverride < Plug
      def run(c : Conn) : Conn
        return c unless c.method == "POST"
        m = c.param("_method").ToUpperInvariant
        c.method = m if m == "PUT" || m == "PATCH" || m == "DELETE"
        c
      end
    end

    # HEAD is routed as GET; the server sends headers only.
    class Head < Plug
      def run(c : Conn) : Conn
        if c.method == "HEAD"
          c.method = "GET"
          c.assign("__head", true)
        end
        c
      end
    end

    class Logger < Plug
      def run(c : Conn) : Conn
        puts "#{c.method} #{c.path}"
        c
      end
    end

    # Serves files under `dir` at URL `prefix`. Never escapes `dir`.
    class Static < Plug
      def initialize(@prefix : String, @dir : String)
        @root = System.IO.Path.GetFullPath(@dir)
      end

      def run(c : Conn) : Conn
        return c unless c.method == "GET" || c.method == "HEAD"
        pre = @prefix.TrimEnd('/') + "/"
        return c unless c.path.StartsWith(pre)
        rel = BunnyKit::Url.decode(c.path.Substring(pre.size))
        full = System.IO.Path.GetFullPath(System.IO.Path.Combine(@root, rel))
        unless full.StartsWith(@root + System.IO.Path.DirectorySeparatorChar) && System.IO.File.Exists(full)
          return c.put_status(404).text("Not Found").halt
        end
        c.put_resp_content_type(BunnyKit::Mime.for_path(full))
        c.put_resp_header("cache-control", "public, max-age=3600")
        c.resp_body = System.IO.File.ReadAllText(full)
        c.halt
      end
    end
  end
end
