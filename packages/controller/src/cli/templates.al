# Source templates for `bunny new` and generators. Placeholders: __APP__, __CLASS__, __TPL__, __TABLE__...
module BunnyCli
  module Templates
    HELP = <<-T
bunny 0.10.0 - Bunny Framework CLI

Usage: bunny <command> [args]

  new <name> [--bunny-path DIR]   create an application
  server                          compile templates and run the app (PORT, BUNNY_ENV)
  compile                         templates/**/*.html.eal -> src/_eal/
  routes                          print the route table
  test                            compile templates and run alice test
  gen.controller <Name> [actions] controller + templates
  gen.live <Name>                 LiveView + template
  gen.channel <Name>              channel
  gen.resource <Name> field:type  CRUD controller + templates + migration (string, text, integer, boolean)
  gen.migration <Name>            empty SQL migration in priv/migrations
  migrate                         apply priv/migrations to DATABASE_URL (PostgreSQL)
  arch                            check workspace dependency rules (framework repo)
  prove [--check]                 prove RULES.al (every package in the framework root, or this app)
  version                         print the version
  help                            this text

Add --force to generators to overwrite files.
T

    MAIN = <<-T
# Composition root: config, wiring, lifecycle. Business logic lives elsewhere.
EalViews.install
App.install_live
router = App.router
argv = System.Environment.GetCommandLineArgs
if argv.Contains("routes")
  for line in router.routes
    puts line
  end
elsif argv.Contains("migrate")
  url = System.Environment.GetEnvironmentVariable("DATABASE_URL") || ""
  if url == ""
    puts "set DATABASE_URL (e.g. Host=127.0.0.1;Port=5432;Username=app;Password=app;Database=app)"
  else
    for f in BunnyPg::Migrator.new(url, "priv/migrations").run
      puts "migrated " + f
    end
  end
else
  sockets = BunnyLive::SocketHandler.new(App::PUBSUB)
  sockets.live
  endpoint = Bunny::Endpoint.new(router)
  endpoint.debug = System.Environment.GetEnvironmentVariable("BUNNY_ENV") != "prod"
  endpoint.plug(Bunny::Plugs::RequestId.new)
  endpoint.plug(Bunny::Plugs::Logger.new)
  endpoint.plug(Bunny::Plugs::Head.new)
  endpoint.plug(Bunny::Plugs::MethodOverride.new)
  endpoint.plug(Bunny::Plugs::Static.new("/static", "priv/static"))
  secret = System.Environment.GetEnvironmentVariable("SECRET_KEY_BASE") || "dev-only-secret-change-me-in-production-0123456789"
  endpoint.plug(Bunny::Plugs::Session.new(secret))
  endpoint.plug(BunnyLive::Assets.new)
  endpoint.plug(sockets.mount("/socket"))
  port = Int32.Parse(System.Environment.GetEnvironmentVariable("PORT") || "4000")
  server = BunnyServer::Server.new(endpoint, "0.0.0.0", port)
  server.start
  puts "__APP__ is down the Bunny Hole at http://localhost:" + port.to_s
  server.join
end
T

    ROUTER = <<-T
# Routes, pipelines and app-wide singletons for __APP__.
module App
  PUBSUB = BunnyLive::PubSub.new
  # PostgreSQL when DATABASE_URL is set (run `bunny migrate`), in-memory otherwise.
  REPO = Bunny::Repo.new(App.adapter)

  def self.adapter : Bunny::Adapter
    url = System.Environment.GetEnvironmentVariable("DATABASE_URL") || ""
    return Bunny::MemoryAdapter.new if url == ""
    BunnyPg::PgAdapter.new(url)
  end

  def self.repo : Bunny::Repo
    REPO
  end

  def self.router : Bunny::Router
    r = Bunny::Router.new
    r.pipeline("browser") do |p|
      p.plug(Bunny::Plugs::SecureHeaders.new)
      p.plug(Bunny::Plugs::Csrf.new)
      p.plug(->(c : Bunny::Conn) { App.browser_assigns(c) })
    end
    r.pipeline("api") do |p|
      p.plug(->(c : Bunny::Conn) { c.put_resp_header("cache-control", "no-store") })
    end
    r.scope("/", ["browser"]) do |s|
      s.get("/", ->(c : Bunny::Conn) { PageController.new.home(c) })
      s.get("/counter", ->(c : Bunny::Conn) { BunnyLive::Live.render(c, "counter") })
    end
    r.scope("/api", ["api"]) do |s|
      s.get("/health", ->(c : Bunny::Conn) { c.text("ok") })
    end
    r
  end

  # Layout and assigns every browser page gets.
  def self.browser_assigns(c : Bunny::Conn) : Bunny::Conn
    c.assign("csrf_token", c.csrf_token)
    c.assign("flash_info", c.flash("info"))
    c.assign("flash_error", c.flash("error"))
    Bunny::Controller.put_layout(c, "layouts/app")
  end

  def self.install_live : Nil
    BunnyLive::Live.register("counter", ->() { CounterLive.new.as(BunnyLive::LiveView) })
  end
end
T

    PAGE_CONTROLLER = <<-T
class PageController < Bunny::Controller
  def home(c : Bunny::Conn) : Bunny::Conn
    c.assign("message", "You fell down the Bunny Hole.")
    render(c, "page/home")
  end
end
T

    COUNTER_LIVE = <<-T
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
T

    LAYOUT = <<-T
<%@ inner_content : String, csrf_token : String, flash_info : String, flash_error : String %>
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="csrf-token" content="<%= csrf_token %>">
  <title>__APP__</title>
  <link rel="stylesheet" href="/static/app.css">
</head>
<body>
  <header><a href="/">__APP__</a></header>
  <main>
    <% if flash_info.size > 0 %><p class="flash info"><%= flash_info %></p><% end %>
    <% if flash_error.size > 0 %><p class="flash error"><%= flash_error %></p><% end %>
    <%== inner_content %>
  </main>
</body>
</html>
T

    HOME = <<-T
<%@ message : String %>
<h1>Welcome to Bunny</h1>
<p><%= message %></p>
<p><a href="/counter">Try the live counter</a></p>
T

    COUNTER = <<-T
<%@ count : Int32 %>
<h2>Count: <%= count %></h2>
<button bunny-click="dec">-</button>
<button bunny-click="inc">+</button>
T

    CSS = <<-T
body { font-family: system-ui, sans-serif; margin: 0; color: #1f2328; }
header { padding: 12px 24px; border-bottom: 1px solid #ddd; }
header a { font-weight: 700; text-decoration: none; color: inherit; }
main { max-width: 720px; margin: 32px auto; padding: 0 16px; }
button { font-size: 1.1rem; padding: 4px 14px; }
.error { color: #b42318; }
.flash { padding: 8px 12px; border-radius: 6px; }
.flash.info { background: #e6f4ea; }
.flash.error { background: #fdecea; }
T

    APP_TEST = <<-T
def test_home_page
  EalViews.install
  c = App.router.dispatch(Bunny::Conn.new("GET", "/"))
  assert_equal 200, c.status
  assert c.resp_body.Contains("Welcome to Bunny"), c.resp_body
end

def test_health
  assert_equal "ok", App.router.dispatch(Bunny::Conn.new("GET", "/api/health")).resp_body
end
T

    LIVE = <<-T
class __CLASS__ < BunnyLive::LiveView
  def template : String
    "__TPL__"
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
T

    CHANNEL = <<-T
class __CLASS__ < BunnyLive::Channel
  def join(topic : String, payload : Hash(String, Object), s : BunnyLive::Socket) : Bool
    true
  end

  def handle_in(event : String, payload : Hash(String, Object), s : BunnyLive::Socket) : Object?
    broadcast(s, event, payload)
    nil
  end
end
T

    RESOURCE = <<-T
class __CLASS__ < Bunny::Controller
  def index(c : Bunny::Conn) : Bunny::Conn
    c.assign("__TABLE__", App.repo.all("__TABLE__"))
    render(c, "__TABLE__/index")
  end

  def show(c : Bunny::Conn) : Bunny::Conn
    id = 0_i64
    return c.put_status(404).text("Not Found") unless Int64.TryParse(c.param("id"), out id)
    rec = App.repo.get("__TABLE__", id)
    return c.put_status(404).text("Not Found") if rec.nil?
    c.assign(singular, rec.not_nil!)
    render(c, "__TABLE__/show")
  end

  def new_form(c : Bunny::Conn) : Bunny::Conn
    c.assign("errors", "")
    render(c, "__TABLE__/new")
  end

  def create(c : Bunny::Conn) : Bunny::Conn
    result = App.repo.insert("__TABLE__", changeset(c))
    if result.ok?()
      c.put_flash("info", "__SINGULAR__ created")
      return c.redirect("/__TABLE__/" + result.record.not_nil!.id.to_s)
    end
    c.assign("errors", String.Join(", ", result.changeset.errors))
    render(c.put_status(422), "__TABLE__/new")
  end

  def changeset(c : Bunny::Conn) : Bunny::Changeset
    Bunny::Changeset.cast(c.body_params, [__FIELDS__])
__VALIDATIONS__  end

  def singular : String
    "__SINGULAR__"
  end
end
T
  end
end
