class RoomChannel < BunnyLive::Channel
  def join(topic : String, payload : Hash(String, Object), s : BunnyLive::Socket) : Bool
    true
  end

  def handle_in(event : String, payload : Hash(String, Object), s : BunnyLive::Socket) : Object?
    broadcast(s, event, payload)
    nil
  end
end
