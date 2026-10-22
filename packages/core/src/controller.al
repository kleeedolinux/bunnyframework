# Controller: render compiled views (with an optional layout) into the Conn.
module Bunny
  class Controller
    LAYOUT_KEY = "__layout"

    def self.put_layout(c : Conn, name : String) : Conn
      c.assign(LAYOUT_KEY, name)
    end

    def render(c : Conn, template : String) : Conn
      body = Views.fetch(template).render(c.assigns)
      if c.assigns.has_key?(LAYOUT_KEY)
        layout = c.assigns[LAYOUT_KEY].to_s
        if layout.size > 0
          c.assign("inner_content", body)
          body = Views.fetch(layout).render(c.assigns)
        end
      end
      c.html(body)
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
