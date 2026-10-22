# Routes, pipelines and app-wide singletons for hello.
module App
  PUBSUB = BunnyLive::PubSub.new
  REPO = Bunny::Repo.new(Bunny::MemoryAdapter.new)

  def self.repo : Bunny::Repo
    REPO
  end

  def self.router : Bunny::Router
    r = Bunny::Router.new
    r.pipeline("browser") do |p|
      p.plug(Bunny::Plugs::SecureHeaders.new)
      p.plug(->(c : Bunny::Conn) { Bunny::Controller.put_layout(c, "layouts/app") })
    end
    r.pipeline("api") do |p|
      p.plug(->(c : Bunny::Conn) { c.put_resp_header("cache-control", "no-store") })
    end
    r.scope("/", ["browser"]) do |s|
      s.get("/", ->(c : Bunny::Conn) { PageController.new.home(c) })
      s.get("/posts", ->(c : Bunny::Conn) { PostController.new.index(c) })
      s.get("/posts/new", ->(c : Bunny::Conn) { PostController.new.new_form(c) })
      s.get("/posts/:id", ->(c : Bunny::Conn) { PostController.new.show(c) })
      s.post("/posts", ->(c : Bunny::Conn) { PostController.new.create(c) })
      s.get("/clock", ->(c : Bunny::Conn) { BunnyLive::Live.render(c, "clock") })
      s.get("/admin", ->(c : Bunny::Conn) { AdminController.new.dash(c) })
      s.get("/counter", ->(c : Bunny::Conn) { BunnyLive::Live.render(c, "counter") })
    end
    r.scope("/api", ["api"]) do |s|
      s.get("/health", ->(c : Bunny::Conn) { c.text("ok") })
    end
    r
  end

  def self.install_live : Nil
    BunnyLive::Live.register("clock", ->() { ClockLive.new.as(BunnyLive::LiveView) })
    BunnyLive::Live.register("counter", ->() { CounterLive.new.as(BunnyLive::LiveView) })
  end
end
