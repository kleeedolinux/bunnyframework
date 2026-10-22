require "./support"

# Fork/join fan-out and encode-once broadcasts.

def test_fanout_reaches_every_subscriber
  ps = BunnyLive::PubSub.new
  subs = List(Collector).new
  for i in 0...1000
    c = Collector.new
    subs << c
    ps.subscribe("big", c)
  end
  delivered = ps.broadcast("big", "e", obj)
  assert_equal 1000, delivered
  for c in subs
    assert_equal 1, c.got.size
  end
end

def test_envelope_encodes_payload_once
  p = obj
  p["k"] = "v"
  env = BunnyLive::Envelope.new("t", "e", p)
  a = env.payload_json
  b = env.payload_json
  assert_equal "{\"k\":\"v\"}", a
  assert_equal 1, env.encodes
  assert Object.ReferenceEquals(a, b), "cached string reused"
end

def test_socket_frames_use_shared_payload
  ws = FakeWs.new
  s = BunnyLive::Socket.new(BunnyLive::PubSub.new, ws)
  s.join_refs["room:1"] = "7"
  s.channels["room:1"] = BunnyLive::LiveChannel.new
  env = BunnyLive::Envelope.new("room:1", "msg", obj)
  s.deliver_envelope(env)
  assert_equal "[\"7\",null,\"room:1\",\"msg\",{}]", ws.sent[0]
end

def test_changed_slots
  last = ["a", "b", "c"]
  now = ["a", "x", "c", "d"]
  ch = BunnyLive::LiveChannel.changed_slots(last, now)
  assert_equal 4, ch.size
  assert !ch[0], "same"
  assert ch[1], "changed"
  assert !ch[2], "same"
  assert ch[3], "new slot"
end
