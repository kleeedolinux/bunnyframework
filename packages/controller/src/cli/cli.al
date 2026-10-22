# Command dispatch for `bunny`.
module BunnyCli
  module Cli
    VERSION_TEXT = "0.10.0"

    def self.run(args : List(String)) : Int32
      return help if args.size == 0
      cmd = args[0]
      rest = args.GetRange(1, args.size - 1)
      force = rest.Remove("--force")
      cwd = System.IO.Directory.GetCurrentDirectory
      begin
        case cmd
        when "new" then cmd_new(rest)
        when "compile" then cmd_compile(cwd)
        when "server", "s" then cmd_alice(cwd, ["run"].ToList)
        when "routes" then cmd_alice(cwd, ["run", "--", "routes"].ToList)
        when "test" then cmd_alice(cwd, ["test"].ToList)
        when "gen.controller" then gen(cwd, rest, force, "controller")
        when "gen.live" then gen(cwd, rest, force, "live")
        when "gen.channel" then gen(cwd, rest, force, "channel")
        when "gen.resource" then gen(cwd, rest, force, "resource")
        when "arch" then cmd_arch(cwd)
        when "version", "-v", "--version" then say(VERSION_TEXT)
        when "help", "-h", "--help" then help
        else
          System.Console.Error.WriteLine("unknown command: " + cmd)
          help
          1
        end
      rescue e : System.FormatException
        System.Console.Error.WriteLine("error: " + e.Message)
        1
      end
    end

    def self.say(s : String) : Int32
      puts s
      0
    end

    def self.help : Int32
      say(Templates::HELP)
    end

    def self.bunny_path(rest : List(String)) : String
      i = rest.IndexOf("--bunny-path")
      if i >= 0 && i + 1 < rest.size
        p = System.IO.Path.GetFullPath(rest[i + 1])
        rest.RemoveRange(i, 2)
        return p
      end
      env = System.Environment.GetEnvironmentVariable("BUNNY_PATH")
      return env.not_nil! unless env.nil? || env.not_nil!.size == 0
      Arch.find_root(System.AppContext.BaseDirectory)
    end

    def self.cmd_new(rest : List(String)) : Int32
      path = bunny_path(rest)
      if rest.size == 0
        System.Console.Error.WriteLine("usage: bunny new <name>")
        return 1
      end
      if path.size == 0
        System.Console.Error.WriteLine("cannot find the Bunny Framework; pass --bunny-path DIR or set BUNNY_PATH")
        return 1
      end
      name = Names.snake(rest[0])
      dir = System.IO.Path.GetFullPath(rest[0])
      if System.IO.Directory.Exists(dir) && System.IO.Directory.EnumerateFileSystemEntries(dir).Any
        System.Console.Error.WriteLine(dir + " is not empty")
        return 1
      end
      dep_path = path
      dep_path = System.IO.Path.GetRelativePath(dir, path) if dir.StartsWith(path + System.IO.Path.DirectorySeparatorChar)
      for f in Gen.write(dir, Gen.new_app(name, dep_path), false)
        puts "  create " + f
      end
      Compile.run(dir)
      puts ""
      puts "Next: cd " + rest[0] + " && bunny server"
      0
    end

    def self.cmd_compile(cwd : String) : Int32
      n = Compile.run(cwd)
      say("compiled " + n.to_s + " template(s) into src/_eal/")
    end

    def self.cmd_alice(cwd : String, alice_args : List(String)) : Int32
      Compile.run(cwd)
      psi = System.Diagnostics.ProcessStartInfo.new("alice")
      for a in alice_args
        psi.ArgumentList.Add(a)
      end
      psi.UseShellExecute = false
      psi.WorkingDirectory = cwd
      started = System.Diagnostics.Process.Start(psi)
      return 1 if started.nil?
      p = started.not_nil!
      p.WaitForExit
      p.ExitCode
    end

    def self.gen(cwd : String, rest : List(String), force : Bool, kind : String) : Int32
      if rest.size == 0
        System.Console.Error.WriteLine("usage: bunny gen." + kind + " <Name> ...")
        return 1
      end
      name = rest[0]
      extra = rest.GetRange(1, rest.size - 1).ToArray
      plan = List(FileOut).new
      hint = ""
      case kind
      when "controller"
        actions = extra.size == 0 ? ["index"] : extra
        plan = Gen.controller(name, actions)
        hint = "Add routes, e.g. s.get(\"/" + Names.snake(name) + "\", ->(c : Bunny::Conn) { " + Names.camel(Names.snake(name)) + "Controller.new." + actions[0] + "(c) })"
      when "live"
        plan = Gen.live(name)
        base = Names.snake(name)
        hint = "Register in App.install_live: BunnyLive::Live.register(\"" + base + "\", ->() { " + Names.camel(base) + "Live.new.as(BunnyLive::LiveView) })\n" +
        "Route: s.get(\"/" + base + "\", ->(c : Bunny::Conn) { BunnyLive::Live.render(c, \"" + base + "\") })"
      when "channel"
        plan = Gen.channel(name)
        hint = "Register in src/main.al: sockets.channel(\"" + Names.snake(name) + ":*\", ->() { " + Names.camel(Names.snake(name)) + "Channel.new.as(BunnyLive::Channel) })"
      else
        plan = Gen.resource(name, Names.fields(extra))
        hint = "Add to the browser scope in src/router.al:\n" + Gen.resource_routes(name)
      end
      for f in Gen.write(cwd, plan, force)
        puts "  create " + f
      end
      Compile.run(cwd) if System.IO.Directory.Exists(System.IO.Path.Combine(cwd, "templates"))
      puts ""
      say(hint)
    end

    def self.cmd_arch(cwd : String) : Int32
      root = Arch.find_root(cwd)
      if root.size == 0
        System.Console.Error.WriteLine("not inside the Bunny Framework workspace")
        return 1
      end
      v = Arch.violations(root)
      for line in v
        System.Console.Error.WriteLine("violation: " + line)
      end
      return 1 if v.size > 0
      say("architecture ok")
    end
  end
end
