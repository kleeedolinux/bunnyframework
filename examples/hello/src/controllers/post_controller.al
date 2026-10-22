class PostController < Bunny::Controller
  def index(c : Bunny::Conn) : Bunny::Conn
    c.assign("posts", App.repo.all("posts"))
    render(c, "posts/index")
  end

  def show(c : Bunny::Conn) : Bunny::Conn
    id = 0_i64
    return c.put_status(404).text("Not Found") unless Int64.TryParse(c.param("id"), out id)
    rec = App.repo.get("posts", id)
    return c.put_status(404).text("Not Found") if rec.nil?
    c.assign(singular, rec.not_nil!)
    render(c, "posts/show")
  end

  def new_form(c : Bunny::Conn) : Bunny::Conn
    c.assign("errors", "")
    render(c, "posts/new")
  end

  def create(c : Bunny::Conn) : Bunny::Conn
    result = App.repo.insert("posts", changeset(c))
    if result.ok?()
      c.put_flash("info", "post created")
      return c.redirect("/posts/" + result.record.not_nil!.id.to_s)
    end
    c.assign("errors", String.Join(", ", result.changeset.errors))
    render(c.put_status(422), "posts/new")
  end

  def changeset(c : Bunny::Conn) : Bunny::Changeset
    Bunny::Changeset.cast(c.body_params, ["title", "body", "views"])
    .validate_required(["title", "body", "views"])
    .validate_number("views", -2147483648_i64, 2147483647_i64)
  end

  def singular : String
    "post"
  end
end
