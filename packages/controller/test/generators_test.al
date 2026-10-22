require "./support"

def test_new_app_plan
  plan = BunnyCli::Gen.new_app("blog", "/opt/bunny")
  for p in ["alice.toml", "src/main.al", "src/router.al", "src/controllers/page_controller.al", "src/live/counter_live.al", "templates/layouts/app.html.eal", "templates/page/home.html.eal", "templates/live/counter.html.eal", "priv/static/app.css", ".gitignore", "test/router_test.al"]
    assert plan_has(plan, p), "missing #{p}"
  end
  toml = plan_body(plan, "alice.toml")
  assert toml.Contains("name = \"blog\""), toml
  assert toml.Contains("core = { path = \"/opt/bunny/packages/core\" }"), toml
  assert toml.Contains("proxy = { path = \"/opt/bunny/packages/proxy\" }"), toml
  assert plan_body(plan, ".gitignore").Contains("src/_eal/"), "generated views ignored"
end

def test_gen_controller
  plan = BunnyCli::Gen.controller("Posts", ["index", "show"])
  ctrl = plan_body(plan, "src/controllers/posts_controller.al")
  assert ctrl.Contains("class PostsController < Bunny::Controller"), ctrl
  assert ctrl.Contains("def index(c : Bunny::Conn) : Bunny::Conn"), ctrl
  assert ctrl.Contains("render(c, \"posts/show\")"), ctrl
  assert plan_has(plan, "templates/posts/index.html.eal"), "index template"
  assert plan_has(plan, "templates/posts/show.html.eal"), "show template"
end

def test_gen_live
  plan = BunnyCli::Gen.live("Clock")
  src = plan_body(plan, "src/live/clock_live.al")
  assert src.Contains("class ClockLive < BunnyLive::LiveView"), src
  assert src.Contains("\"live/clock\""), src
  assert plan_has(plan, "templates/live/clock.html.eal"), "template"
end

def test_gen_channel
  src = plan_body(BunnyCli::Gen.channel("Room"), "src/channels/room_channel.al")
  assert src.Contains("class RoomChannel < BunnyLive::Channel"), src
end

def test_gen_resource
  plan = BunnyCli::Gen.resource("Post", BunnyCli::Names.fields(["title:string", "views:integer"]))
  ctrl = plan_body(plan, "src/controllers/post_controller.al")
  assert ctrl.Contains("class PostController < Bunny::Controller"), ctrl
  assert ctrl.Contains("Bunny::Changeset.cast(c.body_params, [\"title\", \"views\"])"), ctrl
  assert ctrl.Contains("validate_number(\"views\""), ctrl
  for t in ["index", "show", "new"]
    assert plan_has(plan, "templates/posts/#{t}.html.eal"), "template #{t}"
  end
  assert plan_body(plan, "templates/posts/index.html.eal").Contains("<%@ posts : List(Bunny::Record) %>"), "typed assigns"
end

def test_write_plan_refuses_overwrite
  dir = temp_dir
  plan = BunnyCli::Gen.channel("Room")
  assert_equal 1, BunnyCli::Gen.write(dir, plan, false).size
  assert_equal 0, BunnyCli::Gen.write(dir, plan, false).size
  System.IO.Directory.Delete(dir, true)
end

def test_new_app_has_database_wiring
  plan = BunnyCli::Gen.new_app("blog", "/opt/bunny")
  assert plan_body(plan, "alice.toml").Contains("postgres = { path = \"/opt/bunny/packages/postgres\" }"), "pg dep"
  router = plan_body(plan, "src/router.al")
  assert router.Contains("DATABASE_URL"), router
  assert router.Contains("BunnyPg::PgAdapter.new"), router
  assert plan_body(plan, "src/main.al").Contains("BunnyPg::Migrator.new"), "migrate mode"
  assert plan_has(plan, "priv/migrations/.keep"), "migrations dir"
end

def test_gen_migration
  plan = BunnyCli::Gen.migration("AddTags", "20261022120000")
  assert plan_has(plan, "priv/migrations/20261022120000_add_tags.sql"), "file"
end

def test_gen_resource_writes_typed_migration
  plan = BunnyCli::Gen.resource_with_stamp("Post", BunnyCli::Names.fields(["title:string", "body:text", "views:integer"]), "20261022120000")
  sql = plan_body(plan, "priv/migrations/20261022120000_create_posts.sql")
  assert sql.Contains("CREATE TABLE posts ("), sql
  assert sql.Contains("id bigserial PRIMARY KEY"), sql
  assert sql.Contains("title text NOT NULL"), sql
  assert sql.Contains("views integer NOT NULL"), sql
end
