# JSON API response shapes.
module BunnyApi
  module Render
    def self.error(c : Bunny::Conn, status : Int32, message : String) : Bunny::Conn
      e = Hash(String, Object).new
      e["status"] = status
      e["message"] = message
      body = Hash(String, Object).new
      body["error"] = e
      c.put_status(status).json(body)
    end

    # {"errors": {"field": ["msg", ...]}} with 422.
    def self.changeset_errors(c : Bunny::Conn, cs : Bunny::Changeset) : Bunny::Conn
      fields = Hash(String, Object).new
      for i in 0...cs.errors.size
        f = cs.error_fields[i]
        fields[f] = List(Object).new unless fields.has_key?(f)
        fields[f].as(List(Object)) << cs.errors[i]
      end
      body = Hash(String, Object).new
      body["errors"] = fields
      c.put_status(422).json(body)
    end

    def self.data(c : Bunny::Conn, value : Object) : Bunny::Conn
      body = Hash(String, Object).new
      body["data"] = value
      c.json(body)
    end
  end
end
