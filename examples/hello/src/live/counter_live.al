class CounterLive < BunnyLive::LiveView
  def template : String
    "live/counter"
  end

  def mount(params : Hash(String, Object), s : BunnyLive::LiveState) : Nil
    s.assign("count", 0)
  end

  def handle_event(event : String, params : Hash(String, Object), s : BunnyLive::LiveState) : Nil
    n = s.get("count").as(Int32)
    if event == "inc"
      s.assign("count", n + 1)
    elsif event == "dec"
      s.assign("count", n - 1)
    end
  end

  def handle_info(event : String, payload : Object, s : BunnyLive::LiveState) : Nil
  end
end
