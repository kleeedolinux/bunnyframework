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
  sockets.channel("room:*", ->() { RoomChannel.new.as(BunnyLive::Channel) })
  endpoint = Bunny::Endpoint.new(router)
  endpoint.debug = System.Environment.GetEnvironmentVariable("BUNNY_ENV") != "prod"
  endpoint.plug(Bunny::Plugs::RequestId.new)
  endpoint.plug(Bunny::Plugs::Logger.new)
  endpoint.plug(Bunny::Plugs::Head.new)
  endpoint.plug(Bunny::Plugs::MethodOverride.new)
  endpoint.plug(Bunny::Plugs::Static.new("/static", "priv/static"))
  endpoint.plug(BunnyLive::Assets.new)
  endpoint.plug(sockets.mount("/socket"))
  port = Int32.Parse(System.Environment.GetEnvironmentVariable("PORT") || "4000")
  server = BunnyServer::Server.new(endpoint, "0.0.0.0", port)
  server.start
  puts "hello is down the Bunny Hole at http://localhost:" + port.to_s
  server.join
end
