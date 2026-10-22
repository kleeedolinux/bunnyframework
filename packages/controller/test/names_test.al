require "./support"

def test_inflections
  assert_equal "post", BunnyCli::Names.snake("Post")
  assert_equal "blog_post", BunnyCli::Names.snake("BlogPost")
  assert_equal "BlogPost", BunnyCli::Names.camel("blog_post")
  assert_equal "posts", BunnyCli::Names.plural("post")
  assert_equal "categories", BunnyCli::Names.plural("category")
  assert_equal "boxes", BunnyCli::Names.plural("box")
end

def test_parse_fields
  f = BunnyCli::Names.fields(["title:string", "body:text", "views:integer", "bare"])
  assert_equal 4, f.size
  assert_equal "title", f[0].name
  assert_equal "string", f[0].kind
  assert_equal "integer", f[2].kind
  assert_equal "string", f[3].kind
end
