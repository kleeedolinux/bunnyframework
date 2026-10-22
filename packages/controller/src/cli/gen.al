# Generators: pure functions returning file plans; `write` puts them on disk.
module BunnyCli
  class FileOut
    getter path : String
    getter body : String

    def initialize(@path : String, @body : String)
    end
  end

  module Gen
    def self.fill(tpl : String, name : String) : String
      tpl.Replace("__APP__", name)
    end

    def self.new_app(name : String, bunny_path : String) : List(FileOut)
      p = bunny_path.TrimEnd('/')
      plan = List(FileOut).new
      toml = "[package]\nname = \"#{name}\"\nversion = \"0.1.0\"\nkind = \"exe\"\n\n[dependencies]\n"
      for pkg in ["shared", "core", "realtime", "proxy", "api", "postgres"]
        toml += "#{pkg} = { path = \"#{p}/packages/#{pkg}\" }\n"
      end
      plan << FileOut.new("alice.toml", toml)
      plan << FileOut.new(".gitignore", "bin/\nobj/\n.alice/\nsrc/_eal/\n")
      plan << FileOut.new("src/main.al", fill(Templates::MAIN, name))
      plan << FileOut.new("src/router.al", fill(Templates::ROUTER, name))
      plan << FileOut.new("src/controllers/page_controller.al", Templates::PAGE_CONTROLLER)
      plan << FileOut.new("src/live/counter_live.al", Templates::COUNTER_LIVE)
      plan << FileOut.new("templates/layouts/app.html.eal", fill(Templates::LAYOUT, name))
      plan << FileOut.new("templates/page/home.html.eal", Templates::HOME)
      plan << FileOut.new("templates/live/counter.html.eal", Templates::COUNTER)
      plan << FileOut.new("priv/static/app.css", Templates::CSS)
      plan << FileOut.new("priv/migrations/.keep", "")
      plan << FileOut.new("test/router_test.al", Templates::APP_TEST)
      plan << FileOut.new("README.md", "# #{name}\n\nA Bunny Framework app.\n\n```bash\nbunny server   # http://localhost:4000\nbunny test\nbunny routes\n```\n")
      plan
    end

    def self.controller(name : String, actions : Array(String)) : List(FileOut)
      base = Names.snake(name)
      cls = Names.camel(base) + "Controller"
      sb = System.Text.StringBuilder.new
      sb.Append("class #{cls} < Bunny::Controller\n")
      plan = List(FileOut).new
      first = true
      for a in actions
        sb.Append("\n") unless first
        first = false
        sb.Append("  def #{a}(c : Bunny::Conn) : Bunny::Conn\n    render(c, \"#{base}/#{a}\")\n  end\n")
        plan << FileOut.new("templates/#{base}/#{a}.html.eal", "<h1>#{Names.camel(base)}##{a}</h1>\n<p>Edit templates/#{base}/#{a}.html.eal</p>\n")
      end
      sb.Append("end\n")
      plan.Insert(0, FileOut.new("src/controllers/#{base}_controller.al", sb.ToString))
      plan
    end

    def self.live(name : String) : List(FileOut)
      base = Names.snake(name)
      cls = Names.camel(base) + "Live"
      src = Templates::LIVE.Replace("__CLASS__", cls).Replace("__TPL__", "live/#{base}")
      plan = List(FileOut).new
      plan << FileOut.new("src/live/#{base}_live.al", src)
      plan << FileOut.new("templates/live/#{base}.html.eal", "<%@ message : String %>\n<p><%= message %></p>\n<button bunny-click=\"ping\">ping</button>\n")
      plan
    end

    def self.channel(name : String) : List(FileOut)
      base = Names.snake(name)
      src = Templates::CHANNEL.Replace("__CLASS__", Names.camel(base) + "Channel")
      plan = List(FileOut).new
      plan << FileOut.new("src/channels/#{base}_channel.al", src)
      plan
    end

    # BUNNY_STAMP pins the timestamp (reproducible generation).
    def self.stamp : String
      fixed = System.Environment.GetEnvironmentVariable("BUNNY_STAMP") || ""
      return fixed if fixed.size > 0
      System.DateTime.UtcNow.ToString("yyyyMMddHHmmss")
    end

    def self.migration(name : String, stamp : String) : List(FileOut)
      plan = List(FileOut).new
      plan << FileOut.new("priv/migrations/#{stamp}_#{Names.snake(name)}.sql", "-- #{name}\n")
      plan
    end

    def self.sql_type(kind : String) : String
      return "integer" if kind == "integer"
      return "boolean" if kind == "boolean"
      "text"
    end

    def self.resource_with_stamp(name : String, fields : List(Field), stamp : String) : List(FileOut)
      table = Names.plural(Names.snake(name))
      cols = List(String).new
      cols << "  id bigserial PRIMARY KEY"
      for f in fields
        cols << "  #{f.name} #{sql_type(f.kind)} NOT NULL"
      end
      cols << "  inserted_at timestamptz NOT NULL DEFAULT now()"
      plan = resource(name, fields)
      plan << FileOut.new("priv/migrations/#{stamp}_create_#{table}.sql", "CREATE TABLE #{table} (\n#{String.Join(",\n", cols)}\n);\n")
      plan
    end

    def self.resource(name : String, fields : List(Field)) : List(FileOut)
      base = Names.snake(name)
      table = Names.plural(base)
      cls = Names.camel(base) + "Controller"
      names = List(String).new
      for f in fields
        names << "\"#{f.name}\""
      end
      validations = "    .validate_required([#{String.Join(", ", names)}])\n"
      for f in fields
        validations += "    .validate_number(\"#{f.name}\", -2147483648_i64, 2147483647_i64)\n" if f.kind == "integer"
      end
      src = Templates::RESOURCE.Replace("__CLASS__", cls).Replace("__TABLE__", table).Replace("__FIELDS__", String.Join(", ", names)).Replace("__VALIDATIONS__", validations).Replace("__SINGULAR__", base)
      plan = List(FileOut).new
      plan << FileOut.new("src/controllers/#{base}_controller.al", src)
      title = fields.size > 0 ? fields[0].name : "id"
      index = "<%@ #{table} : List(Bunny::Record) %>\n<h1>#{Names.camel(table)}</h1>\n<a href=\"/#{table}/new\">New #{base}</a>\n<ul>\n<% for r in #{table} %>\n  <li><a href=\"/#{table}/<%= r.id %>\"><%= r[\"#{title}\"] %></a></li>\n<% end %>\n</ul>\n"
      show = "<%@ #{base} : Bunny::Record %>\n<h1>#{Names.camel(base)} <%= #{base}.id %></h1>\n"
      form = "<%@ errors : String %>\n<h1>New #{base}</h1>\n<% if errors.size > 0 %><p class=\"error\"><%= errors %></p><% end %>\n<form method=\"post\" action=\"/#{table}\">\n"
      for f in fields
        show += "<p><b>#{f.name}:</b> <%= #{base}[\"#{f.name}\"] %></p>\n"
        input = f.kind == "text" ? "<textarea name=\"#{f.name}\"></textarea>" : "<input name=\"#{f.name}\"#{f.kind == "integer" ? " type=\"number\"" : ""}>"
        form += "  <label>#{f.name} #{input}</label>\n"
      end
      show += "<a href=\"/#{table}\">Back</a>\n"
      form += "  <button>Save</button>\n</form>\n"
      plan << FileOut.new("templates/#{table}/index.html.eal", index)
      plan << FileOut.new("templates/#{table}/show.html.eal", show)
      plan << FileOut.new("templates/#{table}/new.html.eal", form)
      plan
    end

    # Route lines to paste into src/router.al after `bunny gen.resource`.
    def self.resource_routes(name : String) : String
      base = Names.snake(name)
      table = Names.plural(base)
      cls = Names.camel(base) + "Controller"
      "      s.get(\"/#{table}\", ->(c : Bunny::Conn) { #{cls}.new.index(c) })\n" +
      "      s.get(\"/#{table}/new\", ->(c : Bunny::Conn) { #{cls}.new.new_form(c) })\n" +
      "      s.get(\"/#{table}/:id\", ->(c : Bunny::Conn) { #{cls}.new.show(c) })\n" +
      "      s.post(\"/#{table}\", ->(c : Bunny::Conn) { #{cls}.new.create(c) })\n"
    end

    # Writes files under dir; existing files are kept unless force. Returns written paths.
    def self.write(dir : String, plan : List(FileOut), force : Bool) : List(String)
      written = List(String).new
      for f in plan
        full = System.IO.Path.Combine(dir, f.path)
        next if System.IO.File.Exists(full) && !force
        parent = System.IO.Path.GetDirectoryName(full)
        System.IO.Directory.CreateDirectory(parent.not_nil!) unless parent.nil?
        System.IO.File.WriteAllText(full, f.body)
        written << f.path
      end
      written
    end
  end
end
