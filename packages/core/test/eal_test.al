# EAL (Embedded Alice): templates compiled to Alice view classes.

def test_class_name_from_template_path
  assert_equal "PostsShowView", Bunny::Eal.class_name("posts/show")
  assert_equal "LayoutsAppView", Bunny::Eal.class_name("layouts/app")
  assert_equal "UserProfilesEditFormView", Bunny::Eal.class_name("user_profiles/edit_form")
end

def test_template_name_from_file
  assert_equal "posts/show", Bunny::Eal.template_name("templates", "templates/posts/show.html.eal")
end

def test_compile_static_only
  src = Bunny::Eal.compile("pages/home", "<h1>Hi</h1>")
  assert src.Contains("class PagesHomeView < Bunny::View"), src
  assert src.Contains("[\"<h1>Hi</h1>\"]"), src
  assert src.Contains("out.static(0)"), src
end

def test_compile_typed_assigns
  src = Bunny::Eal.compile("posts/show", "<%@ title : String, tags : Hash(String, Int32) %><p><%= title %></p>")
  assert src.Contains("title = Bunny::View.fetch(a, \"title\", \"posts/show\").as(String)"), src
  assert src.Contains("tags = Bunny::View.fetch(a, \"tags\", \"posts/show\").as(Hash(String, Int32))"), src
end

def test_compile_output_tags
  src = Bunny::Eal.compile("x/y", "<%= a %>|<%== b %>")
  assert src.Contains("out.esc(a)"), src
  assert src.Contains("out.raw(b)"), src
end

def test_statics_and_dynamics_split
  tpl = "<p><%= n %></p><% if ok %><b><%= m %></b><% end %>!"
  assert_equal 3, Bunny::Eal.statics(tpl).size
  src = Bunny::Eal.compile("x/y", tpl)
  assert src.Contains("out.text(\"<b>\")"), src
  assert src.Contains("out.open_dyn"), src
end

def test_string_literals_are_escaped
  src = Bunny::Eal.compile("x/y", "a \"q\" \\ \#{no}\n")
  assert src.Contains("\"a \\\"q\\\" \\\\ \\\#{no}\\n\""), src
end

def test_comments_dropped_and_code_kept
  src = Bunny::Eal.compile("x/y", "<%# hidden %><% for i in 0...2 %><%= i %><% end %>")
  assert !src.Contains("hidden"), src
  assert src.Contains("for i in 0...2"), src
end

def test_unclosed_tag_raises
  raised = false
  begin
    Bunny::Eal.compile("x/y", "<%= oops")
  rescue e : System.FormatException
    raised = true
  end
  assert raised, "unclosed tag"
end

def test_unbalanced_blocks_raise
  raised = false
  begin
    Bunny::Eal.compile("x/y", "<% if a %>x")
  rescue e : System.FormatException
    raised = true
  end
  assert raised, "missing end"
end

def test_eal_out_render_mode
  o = Bunny::EalOut.new(false, ["<p>", "</p>"])
  o.static(0)
  o.open_dyn
  o.esc("<x>")
  o.close_dyn
  o.static(1)
  assert_equal "<p>&lt;x&gt;</p>", o.result
end

def test_eal_out_dynamics_mode
  o = Bunny::EalOut.new(true, ["<p>", "</p>"])
  o.static(0)
  o.open_dyn
  o.raw("a")
  o.text("b")
  o.close_dyn
  o.static(1)
  assert_equal 1, o.dyns.size
  assert_equal "ab", o.dyns[0]
end
