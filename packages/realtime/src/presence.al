# Presence: who is on a topic, broadcast as Phoenix-style presence_diff.
module BunnyLive
  class Presence
    @state : Hash(String, Hash(String, Object)) = Hash(String, Hash(String, Object)).new
    @gate : Object = Object.new

    def initialize(@pubsub : PubSub)
    end

    def track(topic : String, key : String, meta : Hash(String, Object)) : Nil
      System.Threading.Monitor.Enter(@gate)
      begin
        @state[topic] = Hash(String, Object).new unless @state.has_key?(topic)
        @state[topic][key] = meta
      ensure
        System.Threading.Monitor.Exit(@gate)
      end
      @pubsub.broadcast(topic, "presence_diff", diff(key, meta, true))
    end

    def untrack(topic : String, key : String) : Nil
      meta : Object = Hash(String, Object).new
      System.Threading.Monitor.Enter(@gate)
      begin
        return unless @state.has_key?(topic) && @state[topic].has_key?(key)
        meta = @state[topic][key]
        @state[topic].Remove(key)
      ensure
        System.Threading.Monitor.Exit(@gate)
      end
      @pubsub.broadcast(topic, "presence_diff", diff(key, meta, false))
    end

    def list(topic : String) : Hash(String, Object)
      System.Threading.Monitor.Enter(@gate)
      begin
        return Hash(String, Object).new unless @state.has_key?(topic)
        Hash(String, Object).new(@state[topic])
      ensure
        System.Threading.Monitor.Exit(@gate)
      end
    end

    def diff(key : String, meta : Object, joined : Bool) : Hash(String, Object)
      metas = List(Object).new
      metas << meta
      entry = Hash(String, Object).new
      entry["metas"] = metas
      side = Hash(String, Object).new
      side[key] = entry
      d = Hash(String, Object).new
      d["joins"] = joined ? side : Hash(String, Object).new
      d["leaves"] = joined ? Hash(String, Object).new : side
      d
    end
  end
end
