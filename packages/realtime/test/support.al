# Test transport: scripted incoming frames, captured outgoing frames.
class FakeWs < Bunny::WsTransport
  getter sent : List(String) = List(String).new
  getter inbox : List(String) = List(String).new
  property closed : Bool = false

  def receive : String?
    return nil if @inbox.size == 0
    m = @inbox[0]
    @inbox.RemoveAt(0)
    m
  end

  def send(text : String) : Bool
    @sent << text
    true
  end

  def close : Nil
    @closed = true
  end
end

class Collector < BunnyLive::Subscriber
  getter got : List(String) = List(String).new

  def deliver(topic : String, event : String, payload : Object) : Nil
    @got << "#{topic}|#{event}|#{BunnyKit::Json.encode(payload)}"
  end
end

def obj : Hash(String, Object)
  Hash(String, Object).new
end
