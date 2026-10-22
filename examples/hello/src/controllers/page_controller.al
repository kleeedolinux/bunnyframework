class PageController < Bunny::Controller
  def home(c : Bunny::Conn) : Bunny::Conn
    c.assign("message", "You fell down the Bunny Hole.")
    render(c, "page/home")
  end
end
