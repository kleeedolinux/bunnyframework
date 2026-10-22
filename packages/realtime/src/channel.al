# Channels over one WebSocket, Phoenix V2 wire format: [join_ref, ref, topic, event, payload].
module BunnyLive
  module Wire
    def self.frame(join_ref : String?, ref : String?, topic : String, event : String, payload : Object) : String
      l = List(Object).new
      l << nullable(join_ref)
      l << nullable(ref)
      l << topic
      l << event
      l << payload
      BunnyKit::Json.encode(l)
    end

    def self.nullable(s : String?) : Object
      return BunnyKit::Json::NULL if s.nil?
      s.not_nil!
    end

    # Frame around an already-encoded payload (encode-once broadcasts).
    def self.frame_json(join_ref : String?, ref : String?, topic : String, event : String, payload_json : String) : String
      sb = System.Text.StringBuilder.new(payload_json.size + topic.size + event.size + 32)
      sb.Append('[')
      BunnyKit::Json.write(sb, nullable(join_ref))
      sb.Append(',')
      BunnyKit::Json.write(sb, nullable(ref))
      sb.Append(',')
      BunnyKit::Json.write_string(sb, topic)
      sb.Append(',')
      BunnyKit::Json.write_string(sb, event)
      sb.Append(',')
      sb.Append(payload_json)
      sb.Append(']')
      sb.ToString
    end

    def self.reply(status : String, response : Object) : Hash(String, Object)
      h = Hash(String, Object).new
      h["status"] = status
      h["response"] = response
      h
    end

    def self.reason(why : String) : Hash(String, Object)
      h = Hash(String, Object).new
      h["reason"] = why
      h
    end

    def self.str(v : Object) : String?
      return nil if v.is_a?(BunnyKit::JsonNull)
      v.to_s
    end
  end

  abstract class Channel
    property topic : String = ""

    abstract def join(topic : String, payload : Hash(String, Object), s : Socket) : Bool

    # Return a reply payload, or nil for no reply.
    def handle_in(event : String, payload : Hash(String, Object), s : Socket) : Object?
      nil
    end

    def terminate(s : Socket) : Nil
    end

    # Response body of a successful join reply.
    def join_response : Object
      Hash(String, Object).new
    end

    def broadcast(s : Socket, event : String, payload : Object) : Nil
      s.pubsub.broadcast(@topic, event, payload)
    end

    def broadcast_from(s : Socket, event : String, payload : Object) : Nil
      s.pubsub.broadcast_from(s, @topic, event, payload)
    end

    def push(s : Socket, event : String, payload : Object) : Nil
      s.push(@topic, event, payload)
    end
  end

  # One per WebSocket connection. Receives PubSub messages for joined topics.
  class Socket < Subscriber
    getter pubsub : PubSub
    getter transport : Bunny::WsTransport
    getter assigns : Hash(String, Object) = Hash(String, Object).new
    getter channels : Hash(String, Channel) = Hash(String, Channel).new
    getter join_refs : Hash(String, String) = Hash(String, String).new

    def initialize(@pubsub : PubSub, @transport : Bunny::WsTransport)
    end

    def assign(k : String, v : Object) : Nil
      @assigns[k] = v
    end

    def get(k : String) : Object
      @assigns[k]
    end

    def push(topic : String, event : String, payload : Object) : Nil
      @transport.send(Wire.frame(@join_refs.fetch(topic, ""), nil, topic, event, payload))
    end

    def deliver(topic : String, event : String, payload : Object) : Nil
      push(topic, event, payload) if @channels.has_key?(topic)
    end

    def deliver_envelope(env : Envelope) : Nil
      return unless @channels.has_key?(env.topic)
      @transport.send(Wire.frame_json(@join_refs.fetch(env.topic, ""), nil, env.topic, env.event, env.payload_json))
    end
  end

  class SocketHandler < Bunny::Upgrader
    getter pubsub : PubSub
    @routes : List(String) = List(String).new
    @factories : List(Func(Channel)) = List(Func(Channel)).new

    def initialize(@pubsub : PubSub)
    end

    # "room:*" matches any topic starting with "room:"; otherwise exact.
    def channel(pattern : String, factory : Func(Channel)) : SocketHandler
      @routes << pattern
      @factories << factory
      self
    end

    # Route "lv:*" to LiveViews.
    def live : SocketHandler
      channel("lv:*", ->() { LiveChannel.new.as(Channel) })
    end

    def find(topic : String) : Func(Channel)?
      for i in 0...@routes.size
        pat = @routes[i]
        if pat.EndsWith("*")
          return @factories[i] if topic.StartsWith(pat.Substring(0, pat.size - 1))
        elsif pat == topic
          return @factories[i]
        end
      end
      nil
    end

    # Plug: GET <path> or <path>/websocket hands the connection to this handler.
    def mount(path : String) : Bunny::Plug
      MountPlug.new(path, self)
    end

    def take_over(c : Bunny::Conn, ws : Bunny::WsTransport) : Nil
      s = Socket.new(@pubsub, ws)
      begin
        while true
          raw = ws.receive
          break if raw.nil?
          handle_frame(s, raw.not_nil!)
        end
      ensure
        for ch in s.channels.Values
          ch.terminate(s)
        end
        @pubsub.unsubscribe_all(s)
      end
    end

    def handle_frame(s : Socket, raw : String) : Nil
      v = BunnyKit::Json.decode(raw)
      return unless v.is_a?(List(Object))
      f = v.as(List(Object))
      return unless f.size == 5
      join_ref = Wire.str(f[0])
      ref = Wire.str(f[1])
      topic = f[2].to_s
      event = f[3].to_s
      payload = f[4].is_a?(Hash(String, Object)) ? f[4].as(Hash(String, Object)) : Hash(String, Object).new
      ok = Hash(String, Object).new
      if topic == "phoenix" && event == "heartbeat"
        ws_reply(s, join_ref, ref, topic, Wire.reply("ok", ok))
      elsif event == "phx_join"
        join(s, join_ref, ref, topic, payload)
      elsif !s.channels.has_key?(topic)
        ws_reply(s, join_ref, ref, topic, Wire.reply("error", Wire.reason("unmatched topic")))
      elsif event == "phx_leave"
        s.channels[topic].terminate(s)
        s.channels.Remove(topic)
        @pubsub.unsubscribe(topic, s)
        ws_reply(s, join_ref, ref, topic, Wire.reply("ok", ok))
      else
        r = s.channels[topic].handle_in(event, payload, s)
        ws_reply(s, join_ref, ref, topic, Wire.reply("ok", r.not_nil!)) unless r.nil?
      end
    end

    def join(s : Socket, join_ref : String?, ref : String?, topic : String, payload : Hash(String, Object)) : Nil
      factory = find(topic)
      if factory.nil?
        ws_reply(s, join_ref, ref, topic, Wire.reply("error", Wire.reason("unmatched topic")))
        return
      end
      ch = factory.not_nil!.Invoke
      ch.topic = topic
      s.join_refs[topic] = join_ref || ""
      allowed = false
      begin
        allowed = ch.join(topic, payload, s)
      rescue e : System.Exception
        allowed = false
      end
      unless allowed
        ws_reply(s, join_ref, ref, topic, Wire.reply("error", Wire.reason("unauthorized")))
        return
      end
      s.channels[topic] = ch
      @pubsub.subscribe(topic, s)
      ws_reply(s, join_ref, ref, topic, Wire.reply("ok", ch.join_response))
    end

    def ws_reply(s : Socket, join_ref : String?, ref : String?, topic : String, body : Object) : Nil
      s.transport.send(Wire.frame(join_ref, ref, topic, "phx_reply", body))
    end
  end

  class MountPlug < Bunny::Plug
    def initialize(@path : String, @handler : SocketHandler)
    end

    def run(c : Bunny::Conn) : Bunny::Conn
      return c unless c.path == @path || c.path == @path + "/websocket"
      c.upgrader = @handler
      c.halt
    end
  end
end
