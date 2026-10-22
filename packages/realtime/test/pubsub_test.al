require "./support"
def test_subscribe_broadcast_unsubscribe
  ps = BunnyLive::PubSub.new
  a = Collector.new
  b = Collector.new
  ps.subscribe("room:1", a)
  ps.subscribe("room:1", b)
  ps.subscribe("room:2", b)
  p = obj
  p["x"] = 1
  ps.broadcast("room:1", "msg", p)
  assert_equal 1, a.got.size
  assert_equal "room:1|msg|{\"x\":1}", a.got[0]
  ps.broadcast_from(a, "room:1", "msg", p)
  assert_equal 1, a.got.size
  assert_equal 2, b.got.size
  ps.unsubscribe("room:1", a)
  ps.broadcast("room:1", "msg", p)
  assert_equal 1, a.got.size
  assert_equal 1, ps.subscriber_count("room:1")
  ps.unsubscribe_all(b)
  assert_equal 0, ps.subscriber_count("room:2")
end
