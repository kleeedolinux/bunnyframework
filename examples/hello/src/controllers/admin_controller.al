class AdminController < Bunny::Controller
  def dash(c : Bunny::Conn) : Bunny::Conn
    render(c, "admin/dash")
  end
end
