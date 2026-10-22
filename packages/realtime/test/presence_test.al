require "./support"
def test_track_list_untrack
  ps = BunnyLive::PubSub.new
  pr = BunnyLive::Presence.new(ps)
  c = Collector.new
  ps.subscribe("room:1", c)
  meta = obj
  meta["status"] = "online"
  pr.track("room:1", "ana", meta)
  pr.track("room:1", "bo", obj)
  assert_equal 2, pr.list("room:1").size
  assert c.got[0].StartsWith("room:1|presence_diff|{\"joins\":{\"ana\":"), c.got[0]
  pr.untrack("room:1", "ana")
  assert_equal 1, pr.list("room:1").size
  assert c.got[2].Contains("\"leaves\":{\"ana\""), c.got[2]
end
