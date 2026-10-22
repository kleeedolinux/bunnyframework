# Architecture rule: shared <- core <- {api, realtime, proxy, controller}; entrypoints never depend on each other.
module BunnyCli
  module Arch
    def self.allowed(pkg : String) : List(String)
      out = List(String).new
      return out if pkg == "shared"
      out << "shared"
      return out if pkg == "core"
      out << "core"
      out
    end

    def self.check(deps : Hash(String, List(String))) : List(String)
      out = List(String).new
      deps.each do |pkg, ds|
        ok = allowed(pkg)
        for d in ds
          out << "#{pkg} must not depend on #{d}" unless ok.Contains(d)
        end
      end
      out
    end

    def self.find_root(start : String) : String
      dir = System.IO.Path.GetFullPath(start)
      while dir.size > 0
        toml = System.IO.Path.Combine(dir, "alice.toml")
        core = System.IO.Path.Combine(dir, "packages", "core", "alice.toml")
        if System.IO.File.Exists(toml) && System.IO.File.Exists(core) && System.IO.File.ReadAllText(toml).Contains("[workspace]")
          return dir
        end
        parent = System.IO.Directory.GetParent(dir)
        return "" if parent.nil?
        dir = parent.not_nil!.FullName
      end
      ""
    end

    # Local path dependencies of every workspace package.
    def self.workspace_deps(root : String) : Hash(String, List(String))
      out = Hash(String, List(String)).new
      for dir in System.IO.Directory.GetDirectories(System.IO.Path.Combine(root, "packages"))
        toml = System.IO.Path.Combine(dir, "alice.toml")
        next unless System.IO.File.Exists(toml)
        name = System.IO.Path.GetFileName(dir)
        ds = List(String).new
        in_deps = false
        for raw in System.IO.File.ReadAllLines(toml)
          line = raw.Trim
          if line.StartsWith("[")
            in_deps = line == "[dependencies]"
          elsif in_deps && line.Contains("path =")
            ds << line.Substring(0, line.IndexOf("=")).Trim
          end
        end
        out[name] = ds
      end
      out
    end

    def self.violations(root : String) : List(String)
      check(workspace_deps(root))
    end
  end
end
