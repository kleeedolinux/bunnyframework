require "./support"

def test_compile_templates_dir
  dir = temp_dir
  tdir = System.IO.Path.Combine(dir, "templates", "posts")
  System.IO.Directory.CreateDirectory(tdir)
  System.IO.File.WriteAllText(System.IO.Path.Combine(tdir, "show.html.eal"), "<%@ title : String %><h1><%= title %></h1>")
  stale = System.IO.Path.Combine(dir, "src", "_eal")
  System.IO.Directory.CreateDirectory(stale)
  System.IO.File.WriteAllText(System.IO.Path.Combine(stale, "old_view.al"), "# stale")
  n = BunnyCli::Compile.run(dir)
  assert_equal 1, n
  out = System.IO.File.ReadAllText(System.IO.Path.Combine(dir, "src", "_eal", "posts_show_view.al"))
  assert out.Contains("class PostsShowView < Bunny::View"), out
  reg = System.IO.File.ReadAllText(System.IO.Path.Combine(dir, "src", "_eal", "registry.al"))
  assert reg.Contains("Bunny::Views.register(PostsShowView.new)"), reg
  assert !System.IO.File.Exists(System.IO.Path.Combine(stale, "old_view.al")), "stale removed"
  System.IO.Directory.Delete(dir, true)
end
