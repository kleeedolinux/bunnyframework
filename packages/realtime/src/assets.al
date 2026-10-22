# Serves the browser client at /bunny.js (Phoenix V2 socket protocol + LiveView).
module BunnyLive
  class Assets < Bunny::Plug
    JS = <<-JS
(function () {
  if (window.Bunny) return;
  var Socket = function (path) {
    this.path = path || "/socket/websocket";
    this.ref = 0; this.channels = {}; this.pending = {}; this.backoff = 500;
    this.connect();
  };
  Socket.prototype.connect = function () {
    var self = this, proto = location.protocol === "https:" ? "wss://" : "ws://";
    this.ws = new WebSocket(proto + location.host + this.path + "?vsn=2.0.0");
    this.ws.onopen = function () {
      self.backoff = 500;
      for (var t in self.channels) self.channels[t].join();
      self.hb = setInterval(function () { self.send(null, "phoenix", "heartbeat", {}); }, 30000);
    };
    this.ws.onmessage = function (e) {
      var m = JSON.parse(e.data), ref = m[1], topic = m[2], event = m[3], payload = m[4];
      if (event === "phx_reply" && self.pending[ref]) { var cb = self.pending[ref]; delete self.pending[ref]; cb(payload); return; }
      var ch = self.channels[topic];
      if (ch) ch.trigger(event, payload);
    };
    this.ws.onclose = function () {
      clearInterval(self.hb);
      setTimeout(function () { self.connect(); }, self.backoff);
      self.backoff = Math.min(self.backoff * 2, 10000);
    };
  };
  Socket.prototype.send = function (joinRef, topic, event, payload, cb) {
    var ref = String(++this.ref);
    if (cb) this.pending[ref] = cb;
    if (this.ws.readyState === 1) this.ws.send(JSON.stringify([joinRef, ref, topic, event, payload]));
    return ref;
  };
  Socket.prototype.channel = function (topic, params) {
    var ch = new Channel(this, topic, params || {});
    this.channels[topic] = ch;
    return ch;
  };
  var Channel = function (socket, topic, params) {
    this.socket = socket; this.topic = topic; this.params = params; this.handlers = {}; this.joinRef = null;
  };
  Channel.prototype.join = function (cb) {
    var self = this;
    if (cb) this.onJoin = cb;
    this.joinRef = this.socket.send(null, this.topic, "phx_join", this.params, function (r) {
      if (self.onJoin) self.onJoin(r);
    });
    return this;
  };
  Channel.prototype.on = function (event, cb) { this.handlers[event] = cb; return this; };
  Channel.prototype.trigger = function (event, payload) { var h = this.handlers[event]; if (h) h(payload); };
  Channel.prototype.push = function (event, payload, cb) {
    return this.socket.send(this.joinRef, this.topic, event, payload, cb);
  };

  function values(el) {
    var v = {};
    for (var i = 0; i < el.attributes.length; i++) {
      var a = el.attributes[i];
      if (a.name.indexOf("bunny-value-") === 0) v[a.name.slice(12)] = a.value;
    }
    return v;
  }
  function formValues(form) {
    var v = {}, fd = new FormData(form);
    fd.forEach(function (val, key) { v[key] = val; });
    return v;
  }
  var LiveView = function (socket, el) {
    var self = this, name = el.getAttribute("bunny-live");
    this.el = el; this.statics = []; this.dyns = [];
    var params = {};
    new URLSearchParams(location.search).forEach(function (v, k) { params[k] = v; });
    this.ch = socket.channel("lv:" + name + ":" + el.id, { view: name, params: params });
    this.ch.on("diff", function (p) { self.apply(p.diff); });
    this.ch.join(function (r) {
      if (r.status !== "ok") return;
      self.statics = r.response.rendered.s; self.dyns = r.response.rendered.d; self.paint();
    });
    var send = function (event, value) {
      self.ch.push("event", { event: event, value: value }, function (r) { if (r.status === "ok") self.apply(r.response.diff); });
    };
    el.addEventListener("click", function (e) {
      var t = e.target.closest("[bunny-click]");
      if (t && el.contains(t)) { e.preventDefault(); send(t.getAttribute("bunny-click"), values(t)); }
    });
    el.addEventListener("submit", function (e) {
      var f = e.target.closest("form[bunny-submit]");
      if (f) { e.preventDefault(); send(f.getAttribute("bunny-submit"), formValues(f)); }
    });
    el.addEventListener("input", function (e) {
      var f = e.target.closest("[bunny-change]");
      if (f) send(f.getAttribute("bunny-change"), f.tagName === "FORM" ? formValues(f) : { value: e.target.value });
    });
  };
  LiveView.prototype.apply = function (diff) {
    var changed = false;
    for (var k in diff) { this.dyns[+k] = diff[k]; changed = true; }
    if (changed) this.paint();
  };
  LiveView.prototype.paint = function () {
    var html = "";
    for (var i = 0; i < this.dyns.length; i++) html += this.statics[i] + this.dyns[i];
    html += this.statics[this.statics.length - 1];
    var a = document.activeElement, id = a && this.el.contains(a) ? a.id : null;
    var start = a && a.selectionStart, end = a && a.selectionEnd;
    this.el.innerHTML = html;
    if (id) { var n = document.getElementById(id); if (n) { n.focus(); try { n.setSelectionRange(start, end); } catch (_) {} } }
  };

  var socket = null;
  function boot() {
    var els = document.querySelectorAll("[bunny-live]");
    if (!els.length) return;
    socket = socket || new Socket();
    for (var i = 0; i < els.length; i++) if (!els[i].__bunny) els[i].__bunny = new LiveView(socket, els[i]);
  }
  window.Bunny = { Socket: Socket, Channel: Channel, boot: boot };
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", boot); else boot();
})();
JS

    def run(c : Bunny::Conn) : Bunny::Conn
      return c unless c.path == "/bunny.js"
      c.put_resp_content_type("application/javascript")
      c.put_resp_header("cache-control", "public, max-age=3600")
      c.resp_body = JS
      c.halt
    end
  end
end
