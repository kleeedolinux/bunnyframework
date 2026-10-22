# LiveView: stateful views over the socket. Sends statics once, then only changed dynamics.
module BunnyLive
  class LiveState
    getter assigns : Hash(String, Object) = Hash(String, Object).new
    property channel : LiveChannel? = nil

    def assign(k : String, v : Object) : Nil
      @assigns[k] = v
    end

    def get(k : String) : Object
      @assigns[k]
    end

    # Receive PubSub messages on `topic` via LiveView#handle_info.
    def subscribe(topic : String) : Nil
      ch = @channel
      ch.not_nil!.subscribe(topic) unless ch.nil?
    end
  end

  abstract class LiveView
    # Name of the compiled .html.eal template.
    abstract def template : String
    abstract def mount(params : Hash(String, Object), s : LiveState) : Nil

    # Abstract on purpose: Alice only emits virtual methods for abstract or locally overridden ones.
    abstract def handle_event(event : String, params : Hash(String, Object), s : LiveState) : Nil
    abstract def handle_info(event : String, payload : Object, s : LiveState) : Nil
  end

  module Live
    FACTORIES = Hash(String, Func(LiveView)).new

    def self.register(name : String, factory : Func(LiveView)) : Nil
      FACTORIES[name] = factory
    end

    def self.find(name : String) : Func(LiveView)?
      return nil unless FACTORIES.has_key?(name)
      FACTORIES[name]
    end

    def self.params_of(c : Bunny::Conn) : Hash(String, Object)
      p = Hash(String, Object).new
      c.query_params.each { |k, v| p[k] = v }
      c.path_params.each { |k, v| p[k] = v }
      p
    end

    # First (dead) render over HTTP; the client then joins lv:<name>:<id>.
    def self.render(c : Bunny::Conn, name : String) : Bunny::Conn
      factory = find(name)
      raise System.Collections.Generic.KeyNotFoundException.new("no live view #{name}") if factory.nil?
      view = factory.not_nil!.Invoke
      state = LiveState.new
      view.mount(params_of(c), state)
      inner = Bunny::Views.fetch(view.template).render(state.assigns)
      id = System.Guid.NewGuid.ToString("N").Substring(0, 12)
      page = "<div id=\"lv-#{id}\" bunny-live=\"#{BunnyKit::Html.escape(name)}\">#{inner}</div><script src=\"/bunny.js\"></script>"
      c.html(Bunny::Controller.wrap_layout(c, page))
    end
  end

  class LiveChannel < Channel
    @view : LiveView? = nil
    @state : LiveState = LiveState.new
    @last : List(String) = List(String).new
    @socket : Socket? = nil
    @rendered : Object = Hash(String, Object).new
    @gate : Object = Object.new
    @subs : List(String) = List(String).new

    def join(topic : String, payload : Hash(String, Object), s : Socket) : Bool
      name = payload.fetch("view", "").to_s
      factory = Live.find(name)
      return false if factory.nil?
      view = factory.not_nil!.Invoke
      @view = view
      @socket = s
      @state.channel = self
      params = Hash(String, Object).new
      raw = payload.fetch("params", Hash(String, Object).new)
      params = raw.as(Hash(String, Object)) if raw.is_a?(Hash(String, Object))
      view.mount(params, @state)
      tpl = Bunny::Views.fetch(view.template)
      @last = tpl.dynamics(@state.assigns)
      statics = List(Object).new
      for st in tpl.statics
        statics << st
      end
      dyn = List(Object).new
      for d in @last
        dyn << d
      end
      r = Hash(String, Object).new
      r["s"] = statics
      r["d"] = dyn
      out = Hash(String, Object).new
      out["rendered"] = r
      @rendered = out
      true
    end

    def join_response : Object
      @rendered
    end

    def handle_in(event : String, payload : Hash(String, Object), s : Socket) : Object?
      return nil unless event == "event"
      name = payload.fetch("event", "").to_s
      value = payload.fetch("value", Hash(String, Object).new)
      params = value.is_a?(Hash(String, Object)) ? value.as(Hash(String, Object)) : Hash(String, Object).new
      System.Threading.Monitor.Enter(@gate)
      begin
        @view.not_nil!.handle_event(name, params, @state)
        out = Hash(String, Object).new
        out["diff"] = diff
        out
      ensure
        System.Threading.Monitor.Exit(@gate)
      end
    end

    # Changed dynamic slots since the last render: {"<index>": html}.
    def diff : Hash(String, Object)
      tpl = Bunny::Views.fetch(@view.not_nil!.template)
      now = tpl.dynamics(@state.assigns).ToArray
      changed = LiveChannel.changed_slots(@last.ToArray, now)
      d = Hash(String, Object).new
      for i in 0...now.size
        d[i.to_s] = now[i] if changed[i]
      end
      @last = List(String).new(now)
      d
    end

    # Pure, index-independent loop: the compiler parallelizes it for large templates.
    pure def self.changed_slots(borrow last : Array(String), borrow now : Array(String)) : Array(Bool)
      out = Array(Bool).new(now.size)
      for i in 0...now.size
        out[i] = i >= last.size || last[i] != now[i]
      end
      out
    end

    def subscribe(topic : String) : Nil
      s = @socket
      return if s.nil?
      sub = LiveInfo.new(self)
      @subs << topic
      s.not_nil!.pubsub.subscribe(topic, sub)
      @info_sub = sub
    end

    @info_sub : LiveInfo? = nil

    def info(event : String, payload : Object) : Nil
      s = @socket
      return if s.nil?
      System.Threading.Monitor.Enter(@gate)
      begin
        @view.not_nil!.handle_info(event, payload, @state)
        d = diff
        if d.size > 0
          body = Hash(String, Object).new
          body["diff"] = d
          s.not_nil!.push(@topic, "diff", body)
        end
      ensure
        System.Threading.Monitor.Exit(@gate)
      end
    end

    def terminate(s : Socket) : Nil
      sub = @info_sub
      return if sub.nil?
      s.pubsub.unsubscribe_all(sub.not_nil!)
    end
  end

  class LiveInfo < Subscriber
    def initialize(@ch : LiveChannel)
    end

    def deliver(topic : String, event : String, payload : Object) : Nil
      @ch.info(event, payload)
    end
  end
end
