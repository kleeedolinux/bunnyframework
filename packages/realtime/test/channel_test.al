require "./support"
# Phoenix V2 wire protocol: [join_ref, ref, topic, event, payload].

class RoomChannel < BunnyLive::Channel
  def join(topic : String, payload : Hash(String, Object), s : BunnyLive::Socket) : Bool
    return false if topic == "room:locked"
    s.assign("user", payload.fetch("user", "anon").to_s)
    true
  end

  def handle_in(event : String, payload : Hash(String, Object), s : BunnyLive::Socket) : Object?
    if event == "shout"
      out = Hash(String, Object).new
      out["body"] = payload["body"]
      out["user"] = s.get("user")
      broadcast(s, "shout", out)
      return nil
    end
    reply = Hash(String, Object).new
    reply["echo"] = event
    reply
  end
end

def handler_with_rooms : BunnyLive::SocketHandler
  h = BunnyLive::SocketHandler.new(BunnyLive::PubSub.new)
  h.channel("room:*", ->() { RoomChannel.new.as(BunnyLive::Channel) })
  h
end

def test_join_ok_reply
  h = handler_with_rooms
  ws = FakeWs.new
  ws.inbox << "[\"1\",\"1\",\"room:lobby\",\"phx_join\",{\"user\":\"ana\"}]"
  h.take_over(Bunny::Conn.new("GET", "/socket/websocket"), ws)
  assert_equal "[\"1\",\"1\",\"room:lobby\",\"phx_reply\",{\"status\":\"ok\",\"response\":{}}]", ws.sent[0]
end

def test_join_refused_and_unknown_topic
  h = handler_with_rooms
  ws = FakeWs.new
  ws.inbox << "[\"1\",\"1\",\"room:locked\",\"phx_join\",{}]"
  ws.inbox << "[\"2\",\"2\",\"nope:x\",\"phx_join\",{}]"
  h.take_over(Bunny::Conn.new("GET", "/"), ws)
  assert ws.sent[0].Contains("\"status\":\"error\""), ws.sent[0]
  assert ws.sent[1].Contains("unmatched topic"), ws.sent[1]
end

def test_heartbeat
  h = handler_with_rooms
  ws = FakeWs.new
  ws.inbox << "[null,\"9\",\"phoenix\",\"heartbeat\",{}]"
  h.take_over(Bunny::Conn.new("GET", "/"), ws)
  assert_equal "[null,\"9\",\"phoenix\",\"phx_reply\",{\"status\":\"ok\",\"response\":{}}]", ws.sent[0]
end

def test_handle_in_reply_and_not_joined
  h = handler_with_rooms
  ws = FakeWs.new
  ws.inbox << "[\"1\",\"2\",\"room:a\",\"ping\",{}]"
  ws.inbox << "[\"1\",\"1\",\"room:a\",\"phx_join\",{}]"
  ws.inbox << "[\"1\",\"3\",\"room:a\",\"ping\",{}]"
  h.take_over(Bunny::Conn.new("GET", "/"), ws)
  assert ws.sent[0].Contains("unmatched topic"), ws.sent[0]
  assert_equal "[\"1\",\"3\",\"room:a\",\"phx_reply\",{\"status\":\"ok\",\"response\":{\"echo\":\"ping\"}}]", ws.sent[2]
end

def test_broadcast_reaches_other_sockets
  ps = BunnyLive::PubSub.new
  h = BunnyLive::SocketHandler.new(ps)
  h.channel("room:*", ->() { RoomChannel.new.as(BunnyLive::Channel) })
  listener = Collector.new
  ps.subscribe("room:a", listener)
  ws = FakeWs.new
  ws.inbox << "[\"1\",\"1\",\"room:a\",\"phx_join\",{\"user\":\"bo\"}]"
  ws.inbox << "[\"1\",\"2\",\"room:a\",\"shout\",{\"body\":\"hey\"}]"
  h.take_over(Bunny::Conn.new("GET", "/"), ws)
  assert_equal "room:a|shout|{\"body\":\"hey\",\"user\":\"bo\"}", listener.got[0]
  assert_equal "[\"1\",null,\"room:a\",\"shout\",{\"body\":\"hey\",\"user\":\"bo\"}]", ws.sent[1]
end

def test_socket_cleans_up_on_close
  ps = BunnyLive::PubSub.new
  h = BunnyLive::SocketHandler.new(ps)
  h.channel("room:*", ->() { RoomChannel.new.as(BunnyLive::Channel) })
  ws = FakeWs.new
  ws.inbox << "[\"1\",\"1\",\"room:a\",\"phx_join\",{}]"
  h.take_over(Bunny::Conn.new("GET", "/"), ws)
  assert_equal 0, ps.subscriber_count("room:a")
end

def test_mount_plug_sets_upgrader
  h = handler_with_rooms
  c = Bunny::Conn.new("GET", "/socket/websocket")
  c = h.mount("/socket").run(c)
  assert !c.upgrader.nil?, "upgrader set"
  assert c.halted, "halted"
  other = h.mount("/socket").run(Bunny::Conn.new("GET", "/x"))
  assert other.upgrader.nil?, "other paths untouched"
end
