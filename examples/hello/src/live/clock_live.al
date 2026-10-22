class ClockLive < BunnyLive::LiveView
  def template : String
    "live/clock"
  end

  def mount(params : Hash(String, Object), s : BunnyLive::LiveState) : Nil
    s.assign("message", "mounted")
  end

  def handle_event(event : String, params : Hash(String, Object), s : BunnyLive::LiveState) : Nil
    s.assign("message", "got " + event)
  end

  def handle_info(event : String, payload : Object, s : BunnyLive::LiveState) : Nil
  end
end
