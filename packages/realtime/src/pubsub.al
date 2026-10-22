# PubSub: topic fan-out inside the process. Delivery happens on the publisher's thread.
module BunnyLive
  abstract class Subscriber
    abstract def deliver(topic : String, event : String, payload : Object) : Nil

    # Broadcast path; override to reuse the envelope's pre-encoded payload.
    def deliver_envelope(env : Envelope) : Nil
      deliver(env.topic, env.event, env.payload)
    end
  end

  # One broadcast message. The payload is JSON-encoded at most once, however many sockets receive it.
  class Envelope
    getter topic : String
    getter event : String
    getter payload : Object
    getter encodes : Int32 = 0
    @json : String? = nil
    @gate : Object = Object.new

    def initialize(@topic : String, @event : String, @payload : Object)
    end

    def payload_json : String
      cached = @json
      return cached.not_nil! unless cached.nil?
      System.Threading.Monitor.Enter(@gate)
      begin
        again = @json
        return again.not_nil! unless again.nil?
        j = BunnyKit::Json.encode(@payload)
        @encodes += 1
        @json = j
        j
      ensure
        System.Threading.Monitor.Exit(@gate)
      end
    end
  end

  class PubSub
    @topics : Hash(String, List(Subscriber)) = Hash(String, List(Subscriber)).new
    @gate : Object = Object.new

    def subscribe(topic : String, s : Subscriber) : Nil
      System.Threading.Monitor.Enter(@gate)
      begin
        @topics[topic] = List(Subscriber).new unless @topics.has_key?(topic)
        l = @topics[topic]
        l << s unless l.Contains(s)
      ensure
        System.Threading.Monitor.Exit(@gate)
      end
    end

    def unsubscribe(topic : String, s : Subscriber) : Nil
      System.Threading.Monitor.Enter(@gate)
      begin
        if @topics.has_key?(topic)
          @topics[topic].Remove(s)
          @topics.Remove(topic) if @topics[topic].size == 0
        end
      ensure
        System.Threading.Monitor.Exit(@gate)
      end
    end

    def unsubscribe_all(s : Subscriber) : Nil
      System.Threading.Monitor.Enter(@gate)
      begin
        empty = List(String).new
        @topics.each do |t, l|
          l.Remove(s)
          empty << t if l.size == 0
        end
        for t in empty
          @topics.Remove(t)
        end
      ensure
        System.Threading.Monitor.Exit(@gate)
      end
    end

    def subscriber_count(topic : String) : Int32
      System.Threading.Monitor.Enter(@gate)
      begin
        return 0 unless @topics.has_key?(topic)
        @topics[topic].size
      ensure
        System.Threading.Monitor.Exit(@gate)
      end
    end

    def snapshot(topic : String) : List(Subscriber)
      System.Threading.Monitor.Enter(@gate)
      begin
        return List(Subscriber).new unless @topics.has_key?(topic)
        List(Subscriber).new(@topics[topic])
      ensure
        System.Threading.Monitor.Exit(@gate)
      end
    end

    # Below this many subscribers a branch delivers serially; above, it forks.
    FANOUT_LEAF = 64

    # Returns how many subscribers received the message.
    def broadcast(topic : String, event : String, payload : Object) : Int32
      subs = snapshot(topic)
      PubSub.fan_out(subs, 0, subs.size, Envelope.new(topic, event, payload), nil)
    end

    def broadcast_from(sender : Subscriber, topic : String, event : String, payload : Object) : Int32
      subs = snapshot(topic)
      PubSub.fan_out(subs, 0, subs.size, Envelope.new(topic, event, payload), sender)
    end

    # Fork/join: split the subscriber range, deliver both halves in parallel, join.
    def self.fan_out(subs : List(Subscriber), lo : Int32, hi : Int32, env : Envelope, skip : Subscriber?) : Int32
      if hi - lo <= FANOUT_LEAF
        n = 0
        for i in lo...hi
          s = subs[i]
          next if !skip.nil? && s == skip.not_nil!
          s.deliver_envelope(env)
          n += 1
        end
        return n
      end
      mid = lo + (hi - lo) / 2
      left = spawn { PubSub.fan_out(subs, lo, mid, env, skip) }
      right = PubSub.fan_out(subs, mid, hi, env, skip)
      left.Result + right
    end
  end
end
