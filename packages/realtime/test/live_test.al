require "./support"
# LiveView: HTTP render, socket mount, events -> minimal diffs.

class CounterView < Bunny::View
  def initialize
    super("live/counter", ["<p>", "</p><i>", "</i>"])
  end

  def write(a : Hash(String, Object), out : Bunny::EalOut) : Nil
    count = Bunny::View.fetch(a, "count", "live/counter").as(Int32)
    label = Bunny::View.fetch(a, "label", "live/counter").as(String)
    out.static(0)
    out.open_dyn
    out.esc(count)
    out.close_dyn
    out.static(1)
    out.open_dyn
    out.esc(label)
    out.close_dyn
    out.static(2)
  end
end

class CounterLive < BunnyLive::LiveView
  def template : String
    "live/counter"
  end

  def mount(params : Hash(String, Object), s : BunnyLive::LiveState) : Nil
    s.assign("count", 0)
    s.assign("label", "clicks")
  end

  def handle_event(event : String, params : Hash(String, Object), s : BunnyLive::LiveState) : Nil
    s.assign("count", s.get("count").as(Int32) + 1) if event == "inc"
  end

  def handle_info(event : String, payload : Object, s : BunnyLive::LiveState) : Nil
  end
end

def live_setup : BunnyLive::SocketHandler
  Bunny::Views.register(CounterView.new)
  BunnyLive::Live.register("counter", ->() { CounterLive.new.as(BunnyLive::LiveView) })
  h = BunnyLive::SocketHandler.new(BunnyLive::PubSub.new)
  h.live
  h
end

def test_http_render_wraps_container
  live_setup
  c = BunnyLive::Live.render(Bunny::Conn.new("GET", "/counter"), "counter")
  assert c.resp_body.Contains("bunny-live=\"counter\""), c.resp_body
  assert c.resp_body.Contains("<p>0</p><i>clicks</i>"), c.resp_body
  assert c.resp_body.Contains("<script src=\"/bunny.js\"></script>"), c.resp_body
end

def test_socket_join_then_event_sends_only_changed_dynamics
  h = live_setup
  ws = FakeWs.new
  ws.inbox << "[\"1\",\"1\",\"lv:counter:abc\",\"phx_join\",{\"view\":\"counter\"}]"
  ws.inbox << "[\"1\",\"2\",\"lv:counter:abc\",\"event\",{\"event\":\"inc\",\"value\":{}}]"
  ws.inbox << "[\"1\",\"3\",\"lv:counter:abc\",\"event\",{\"event\":\"noop\",\"value\":{}}]"
  h.take_over(Bunny::Conn.new("GET", "/"), ws)
  assert_equal "[\"1\",\"1\",\"lv:counter:abc\",\"phx_reply\",{\"status\":\"ok\",\"response\":{\"rendered\":{\"s\":[\"<p>\",\"</p><i>\",\"</i>\"],\"d\":[\"0\",\"clicks\"]}}}]", ws.sent[0]
  assert_equal "[\"1\",\"2\",\"lv:counter:abc\",\"phx_reply\",{\"status\":\"ok\",\"response\":{\"diff\":{\"0\":\"1\"}}}]", ws.sent[1]
  assert_equal "[\"1\",\"3\",\"lv:counter:abc\",\"phx_reply\",{\"status\":\"ok\",\"response\":{\"diff\":{}}}]", ws.sent[2]
end

def test_unknown_live_view_refused
  h = live_setup
  ws = FakeWs.new
  ws.inbox << "[\"1\",\"1\",\"lv:ghost:x\",\"phx_join\",{\"view\":\"ghost\"}]"
  h.take_over(Bunny::Conn.new("GET", "/"), ws)
  assert ws.sent[0].Contains("\"status\":\"error\""), ws.sent[0]
end

def test_bunny_js_asset
  c = BunnyLive::Assets.new.run(Bunny::Conn.new("GET", "/bunny.js"))
  assert c.halted, "served"
  assert_equal "application/javascript", c.resp_headers["content-type"]
  assert c.resp_body.Contains("phx_join"), "client speaks phoenix protocol"
end

class LiveLayoutView < Bunny::View
  def initialize
    super("layouts/live_test", ["<html>", "</html>"])
  end

  def write(a : Hash(String, Object), out : Bunny::EalOut) : Nil
    inner = Bunny::View.fetch(a, "inner_content", "layouts/live_test").as(String)
    out.static(0)
    out.open_dyn
    out.raw(inner)
    out.close_dyn
    out.static(1)
  end
end

def test_http_render_uses_layout
  live_setup
  Bunny::Views.register(LiveLayoutView.new)
  c = Bunny::Controller.put_layout(Bunny::Conn.new("GET", "/counter"), "layouts/live_test")
  c = BunnyLive::Live.render(c, "counter")
  assert c.resp_body.StartsWith("<html><div id=\"lv-"), c.resp_body
  assert c.resp_body.EndsWith("</script></html>"), c.resp_body
end
