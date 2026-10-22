require "./support"

# Workspace dependency direction: shared <- core <- {api, realtime, proxy, controller}.

def test_dependency_direction
  root = BunnyCli::Arch.find_root(System.IO.Directory.GetCurrentDirectory)
  violations = BunnyCli::Arch.violations(root)
  assert_equal "", String.Join("; ", violations)
end

def test_rule_detects_violation
  deps = Hash(String, List(String)).new
  deps["core"] = ["realtime"].ToList
  deps["realtime"] = ["core", "shared"].ToList
  v = BunnyCli::Arch.check(deps)
  assert_equal 1, v.size
  assert_equal "core must not depend on realtime", v[0]
end
