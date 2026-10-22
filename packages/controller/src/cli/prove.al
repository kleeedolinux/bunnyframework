# bunny prove: runs `alice prove` on RULES.al plus the dependency-free files named in its
# `# prove-with:` header. In the framework root it proves every package that has RULES.al.
module BunnyCli
  module Prove
    HEADER = "# prove-with:"

    def self.files_of(rules : String) : List(String)
      out = List(String).new
      out << "RULES.al"
      for raw in rules.split("\n")
        line = raw.Trim
        next unless line.StartsWith(HEADER)
        for f in line.Substring(HEADER.size).split(" ")
          out << f if f.size > 0
        end
      end
      out
    end

    def self.targets(root : String) : List(String)
      out = List(String).new
      for dir in System.IO.Directory.GetDirectories(System.IO.Path.Combine(root, "packages"))
        out << dir if System.IO.File.Exists(System.IO.Path.Combine(dir, "RULES.al"))
      end
      out.Sort
      out
    end

    def self.run_in(dir : String, check : Bool) : Int32
      rules = System.IO.File.ReadAllText(System.IO.Path.Combine(dir, "RULES.al"))
      psi = System.Diagnostics.ProcessStartInfo.new("alice")
      psi.ArgumentList.Add("prove")
      psi.ArgumentList.Add("--check") if check
      for f in files_of(rules)
        psi.ArgumentList.Add(f)
      end
      psi.UseShellExecute = false
      psi.WorkingDirectory = dir
      started = System.Diagnostics.Process.Start(psi)
      return 1 if started.nil?
      p = started.not_nil!
      p.WaitForExit
      p.ExitCode
    end

    def self.run(cwd : String, check : Bool) : Int32
      root = Arch.find_root(cwd)
      dirs = List(String).new
      if System.IO.File.Exists(System.IO.Path.Combine(cwd, "RULES.al"))
        dirs << cwd
      elsif root.size > 0
        dirs = targets(root)
      end
      if dirs.size == 0
        System.Console.Error.WriteLine("no RULES.al here")
        return 1
      end
      failed = 0
      for d in dirs
        puts "== prove " + System.IO.Path.GetFileName(d)
        failed += 1 if run_in(d, check) != 0
      end
      failed == 0 ? 0 : 1
    end
  end
end
