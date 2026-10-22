# Controller rendering through compiled views and layouts.

class TestGreetView < Bunny::View
  def initialize
    super("test/greet", ["<p>", "</p>"])
  end

  def write(a : Hash(String, Object), out : Bunny::EalOut) : Nil
    name = Bunny::View.fetch(a, "name", "test/greet").as(String)
    out.static(0)
    out.open_dyn
    out.esc(name)
    out.close_dyn
    out.static(1)
  end
end

class TestLayoutView < Bunny::View
  def initialize
    super("layouts/test", ["<main>", "</main>"])
  end

  def write(a : Hash(String, Object), out : Bunny::EalOut) : Nil
    inner = Bunny::View.fetch(a, "inner_content", "layouts/test").as(String)
    out.static(0)
    out.open_dyn
    out.raw(inner)
    out.close_dyn
    out.static(1)
  end
end

class GreetController < Bunny::Controller
  def show(c : Bunny::Conn) : Bunny::Conn
    c.assign("name", "<ana>")
    render(c, "test/greet")
  end
end

def test_render_without_layout
  Bunny::Views.register(TestGreetView.new)
  c = GreetController.new.show(Bunny::Conn.new("GET", "/"))
  assert_equal "<p>&lt;ana&gt;</p>", c.resp_body
  assert_equal "text/html; charset=utf-8", c.resp_headers["content-type"]
end

def test_render_with_layout
  Bunny::Views.register(TestGreetView.new)
  Bunny::Views.register(TestLayoutView.new)
  c = Bunny::Conn.new("GET", "/")
  Bunny::Controller.put_layout(c, "layouts/test")
  c = GreetController.new.show(c)
  assert_equal "<main><p>&lt;ana&gt;</p></main>", c.resp_body
end

def test_view_dynamics
  a = Hash(String, Object).new
  a["name"] = "z"
  d = TestGreetView.new.dynamics(a)
  assert_equal 1, d.size
  assert_equal "z", d[0]
end

def test_missing_assign_message
  msg = ""
  begin
    TestGreetView.new.render(Hash(String, Object).new)
  rescue e : System.Collections.Generic.KeyNotFoundException
    msg = e.Message
  end
  assert_equal "template test/greet needs assign 'name'", msg
end
