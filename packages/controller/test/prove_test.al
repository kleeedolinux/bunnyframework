require "./support"

def test_prove_files_from_header
  files = BunnyCli::Prove.files_of("# prove-with: src/a.al src/b.al\n# rules\nrule x(i in 0..1)\n  true\nend\n")
  assert_equal "RULES.al src/a.al src/b.al", String.Join(" ", files)
end

def test_prove_files_default
  assert_equal "RULES.al", String.Join(" ", BunnyCli::Prove.files_of("rule x(i in 0..1)\n  true\nend\n"))
end

def test_prove_targets_in_framework
  root = BunnyCli::Arch.find_root(System.IO.Directory.GetCurrentDirectory)
  t = BunnyCli::Prove.targets(root)
  names = List(String).new
  for d in t
    names << System.IO.Path.GetFileName(d)
  end
  names.Sort
  assert_equal "api core postgres realtime shared", String.Join(" ", names)
end
