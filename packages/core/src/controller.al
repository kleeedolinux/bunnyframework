# Controller: render compiled views (with an optional layout) into the Conn.
module Bunny
  abstract class Controller
    LAYOUT_KEY = "__layout"

    def self.put_layout(c : Conn, name : String) : Conn
      c.assign(LAYOUT_KEY, name)
    end

    def render(c : Conn, template : String) : Conn
      c.html(Controller.wrap_layout(c, Views.fetch(template).render(c.assigns)))
    end

    # Renders the layout set by put_layout around body (as inner_content), or returns body.
    def self.wrap_layout(c : Conn, body : String) : String
      return body unless c.assigns.has_key?(LAYOUT_KEY)
      layout = c.assigns[LAYOUT_KEY].to_s
      return body if layout.size == 0
      c.assign("inner_content", body)
      Views.fetch(layout).render(c.assigns)
    end

    def render(c : Conn, template : String, status : Int32) : Conn
      render(c.put_status(status), template)
    end

    def json(c : Conn, value : Object?) : Conn
      c.json(value)
    end

    def text(c : Conn, body : String) : Conn
      c.text(body)
    end

    def redirect(c : Conn, to : String) : Conn
      c.redirect(to)
    end
  end
end
