# Kestrel-backed server: real sockets, real HTTP client.

class EchoUpgrader < Bunny::Upgrader
  def take_over(c : Bunny::Conn, ws : Bunny::WsTransport) : Nil
    while true
      m = ws.receive
      break if m.nil?
      ws.send("echo:#{m.not_nil!}")
    end
  end
end

def ws_route(c : Bunny::Conn) : Bunny::Conn
  c.upgrader = EchoUpgrader.new
  c
end

def start_test_server : BunnyServer::Server
  r = Bunny::Router.new
  r.get("/", ->(c : Bunny::Conn) { c.put_resp_cookie("k", "v").text("root") })
  r.post("/echo", ->(c : Bunny::Conn) { c.text("got #{c.param("x")}") })
  r.get("/ws", ->(c : Bunny::Conn) { ws_route(c) })
  s = BunnyServer::Server.new(Bunny::Endpoint.new(r), "127.0.0.1", 0)
  s.start
  s
end

def test_get
  s = start_test_server
  http = System.Net.Http.HttpClient.new
  resp = http.GetAsync("http://127.0.0.1:#{s.port}/").Result
  assert_equal System.Net.HttpStatusCode.OK, resp.StatusCode
  assert_equal "root", resp.Content.ReadAsStringAsync.Result
  assert resp.Headers.GetValues("set-cookie").First.StartsWith("k=v"), "cookie"
  s.stop
end

def test_post_form_and_404
  s = start_test_server
  http = System.Net.Http.HttpClient.new
  body = System.Net.Http.StringContent.new("x=9", System.Text.Encoding.UTF8, "application/x-www-form-urlencoded")
  resp = http.PostAsync("http://127.0.0.1:#{s.port}/echo", body).Result
  assert_equal "got 9", resp.Content.ReadAsStringAsync.Result
  nf = http.GetAsync("http://127.0.0.1:#{s.port}/nope").Result
  assert_equal System.Net.HttpStatusCode.NotFound, nf.StatusCode
  s.stop
end

def test_websocket_upgrade
  s = start_test_server
  ws = System.Net.WebSockets.ClientWebSocket.new
  ws.ConnectAsync(System.Uri.new("ws://127.0.0.1:#{s.port}/ws"), System.Threading.CancellationToken.None).Wait
  out = System.Text.Encoding.UTF8.GetBytes("hi")
  ws.SendAsync(System.ArraySegment(UInt8).new(out), System.Net.WebSockets.WebSocketMessageType.Text, true, System.Threading.CancellationToken.None).Wait
  buf = Array(UInt8).new(1024)
  r = ws.ReceiveAsync(System.ArraySegment(UInt8).new(buf), System.Threading.CancellationToken.None).Result
  assert_equal "echo:hi", System.Text.Encoding.UTF8.GetString(buf, 0, r.Count)
  ws.Abort
  s.stop
end
