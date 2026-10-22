# Server: Kestrel (NuGet) moves the bytes; the Bunny Hole endpoint handles every request.
module BunnyServer
  # Blocking facade over System.Net.WebSockets.WebSocket; one reader thread, many senders.
  class KestrelSocket < Bunny::WsTransport
    @gate : System.Threading.SemaphoreSlim = System.Threading.SemaphoreSlim.new(1, 1)

    def initialize(@ws : System.Net.WebSockets.WebSocket)
    end

    def receive : String?
      buf = Array(UInt8).new(8192)
      acc = System.IO.MemoryStream.new
      begin
        while true
          r = @ws.ReceiveAsync(System.ArraySegment(UInt8).new(buf), System.Threading.CancellationToken.None).GetAwaiter.GetResult
          return nil if r.MessageType == System.Net.WebSockets.WebSocketMessageType.Close
          acc.Write(buf, 0, r.Count)
          return System.Text.Encoding.UTF8.GetString(acc.ToArray) if r.EndOfMessage
        end
      rescue e : System.Exception
        return nil
      end
      nil
    end

    def send(text : String) : Bool
      data = System.Text.Encoding.UTF8.GetBytes(text)
      @gate.Wait
      begin
        @ws.SendAsync(System.ArraySegment(UInt8).new(data), System.Net.WebSockets.WebSocketMessageType.Text, true, System.Threading.CancellationToken.None).GetAwaiter.GetResult
        true
      rescue e : System.Exception
        false
      ensure
        @gate.Release
      end
    end

    def close : Nil
      begin
        @ws.CloseAsync(System.Net.WebSockets.WebSocketCloseStatus.NormalClosure, "", System.Threading.CancellationToken.None).GetAwaiter.GetResult
      rescue e : System.Exception
      end
    end
  end

  class Server
    getter port : Int32
    property max_body : Int64 = 8_388_608_i64
    @host_obj : Microsoft.AspNetCore.Hosting.IWebHost? = nil

    def initialize(@endpoint : Bunny::Endpoint, @host : String, @port : Int32)
    end

    def start : Nil
      @port = Server.free_port(@host) if @port == 0
      b = Microsoft.AspNetCore.Hosting.WebHostBuilder.new
      Microsoft.AspNetCore.Hosting.WebHostBuilderKestrelExtensions.UseKestrel(b, ->(o : Microsoft.AspNetCore.Server.Kestrel.Core.KestrelServerOptions) { kestrel_options(o) })
      Microsoft.AspNetCore.Hosting.WebHostBuilderExtensions.Configure(b, ->(app : Microsoft.AspNetCore.Builder.IApplicationBuilder) { pipeline(app) })
      h = b.Build
      h.Start
      @host_obj = h
    end

    def self.free_port(host : String) : Int32
      l = System.Net.Sockets.TcpListener.new(System.Net.IPAddress.Parse(host), 0)
      l.Start
      p = l.LocalEndpoint.as(System.Net.IPEndPoint).Port
      l.Stop
      p
    end

    def kestrel_options(o : Microsoft.AspNetCore.Server.Kestrel.Core.KestrelServerOptions) : Nil
      o.AddServerHeader = false
      o.AllowSynchronousIO = true
      o.Limits.MaxRequestBodySize = @max_body
      o.Listen(System.Net.IPAddress.Parse(@host), @port)
    end

    def pipeline(app : Microsoft.AspNetCore.Builder.IApplicationBuilder) : Nil
      Microsoft.AspNetCore.Builder.WebSocketMiddlewareExtensions.UseWebSockets(app)
      Microsoft.AspNetCore.Builder.RunExtensions.Run(app, ->(ctx : Microsoft.AspNetCore.Http.HttpContext) { handle(ctx) })
    end

    def stop : Nil
      h = @host_obj
      h.not_nil!.StopAsync.GetAwaiter.GetResult unless h.nil?
    end

    # Blocks until the process is stopped (for `bunny server`).
    def join : Nil
      System.Threading.Thread.Sleep(System.Threading.Timeout.Infinite)
    end

    def run_socket(upgrader : Bunny::Upgrader, c : Bunny::Conn, sock : KestrelSocket) : Nil
      begin
        upgrader.take_over(c, sock)
      ensure
        sock.close
      end
    end

    def to_conn(ctx : Microsoft.AspNetCore.Http.HttpContext) : Bunny::Conn
      req = ctx.Request
      c = Bunny::Conn.new(req.Method, req.Path.ToUriComponent + req.QueryString.ToUriComponent)
      for h in req.Headers
        c.req_headers[h.Key.ToLowerInvariant] = h.Value.ToString
      end
      ip = ctx.Connection.RemoteIpAddress
      c.remote_ip = ip.ToString unless ip.nil?
      if req.ContentLength.GetValueOrDefault > 0 || req.Headers.ContainsKey("Transfer-Encoding")
        reader = System.IO.StreamReader.new(req.Body, System.Text.Encoding.UTF8)
        c.body = reader.ReadToEnd
      end
      c
    end

    def handle(ctx : Microsoft.AspNetCore.Http.HttpContext) : System.Threading.Tasks.Task
      c = @endpoint.run(to_conn(ctx))
      up = c.upgrader
      if !up.nil? && ctx.WebSockets.IsWebSocketRequest
        ws = ctx.WebSockets.AcceptWebSocketAsync.GetAwaiter.GetResult
        sock = KestrelSocket.new(ws)
        upgrader = up.not_nil!
        return System.Threading.Tasks.Task.Factory.StartNew(-> { run_socket(upgrader, c, sock) }, System.Threading.Tasks.TaskCreationOptions.LongRunning)
      end
      res = ctx.Response
      res.StatusCode = c.status
      c.resp_headers.each { |k, v| res.Headers[k] = Microsoft.Extensions.Primitives.StringValues.new(v) }
      if c.resp_cookies.size > 0
        res.Headers["set-cookie"] = Microsoft.Extensions.Primitives.StringValues.new(c.resp_cookies.ToArray)
      end
      data = System.Text.Encoding.UTF8.GetBytes(c.resp_body)
      res.ContentLength = data.size.to_i64
      res.Body.Write(data, 0, data.size) unless c.method == "HEAD"
      System.Threading.Tasks.Task.CompletedTask
    end
  end
end
