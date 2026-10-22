def temp_dir : String
  d = System.IO.Path.Combine(System.IO.Path.GetTempPath, "bunny-cli-#{System.Guid.NewGuid.ToString("N")}")
  System.IO.Directory.CreateDirectory(d)
  d
end

def plan_has(plan : List(BunnyCli::FileOut), path : String) : Bool
  plan.any? { |f| f.path == path }
end

def plan_body(plan : List(BunnyCli::FileOut), path : String) : String
  for f in plan
    return f.body if f.path == path
  end
  ""
end
