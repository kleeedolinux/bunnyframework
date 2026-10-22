# Conn: request in, response out. Every plug is Conn -> Conn.
module Bunny
  class Conn
    property method : String
    property path : String
    property query_string : String = ""
    property req_headers : Hash(String, String) = Hash(String, String).new
    property body : String = ""
    property remote_ip : String = ""
    property status : Int32 = 200
    property resp_headers : Hash(String, String) = Hash(String, String).new
    property resp_body : String = ""
    property halted : Bool = false
    property assigns : Hash(String, Object) = Hash(String, Object).new
    property path_params : Hash(String, String) = Hash(String, String).new
    # Set by a plug that takes over the socket (e.g. WebSocket upgrade).
    property upgrade : String = ""
    @query_cache : Hash(String, String)? = nil
    @body_cache : Hash(String, String)? = nil

    def initialize(@method : String, target : String)
      q = target.IndexOf("?")
      if q < 0
        @path = target
      else
        @path = target.Substring(0, q)
        @query_string = target.Substring(q + 1)
      end
    end

    def query_params : Hash(String, String)
      cached = @query_cache
      return cached.not_nil! unless cached.nil?
      parsed = BunnyKit::Url.parse_query(@query_string)
      @query_cache = parsed
      parsed
    end

    def body_params : Hash(String, String)
      cached = @body_cache
      return cached.not_nil! unless cached.nil?
      parsed = Hash(String, String).new
      ctype = req_header("content-type")
      if @body.size > 0
        if ctype.StartsWith("application/x-www-form-urlencoded")
          parsed = BunnyKit::Url.parse_query(@body)
        elsif ctype.StartsWith("application/json")
          v = BunnyKit::Json.decode(@body)
          if v.is_a?(Hash(String, Object))
            v.as(Hash(String, Object)).each { |k, x| parsed[k] = x.to_s }
          end
        end
      end
      @body_cache = parsed
      parsed
    end

    # Lookup order: path params, body params, query params.
    def param(name : String) : String
      return @path_params[name] if @path_params.has_key?(name)
      b = body_params
      return b[name] if b.has_key?(name)
      query_params.fetch(name, "")
    end

    def has_param?(name : String) : Bool
      @path_params.has_key?(name) || body_params.has_key?(name) || query_params.has_key?(name)
    end

    def req_header(name : String) : String
      @req_headers.fetch(name, "")
    end

    def assign(key : String, value : Object) : Conn
      @assigns[key] = value
      self
    end

    def put_status(code : Int32) : Conn
      @status = code
      self
    end

    def put_resp_header(name : String, value : String) : Conn
      @resp_headers[name] = value
      self
    end

    def put_resp_content_type(ctype : String) : Conn
      put_resp_header("content-type", ctype)
    end

    def send_resp(code : Int32, body : String) : Conn
      @status = code
      @resp_body = body
      self
    end

    def text(body : String) : Conn
      put_resp_content_type("text/plain; charset=utf-8")
      @resp_body = body
      self
    end

    def html(body : String) : Conn
      put_resp_content_type("text/html; charset=utf-8")
      @resp_body = body
      self
    end

    def json(value : Object?) : Conn
      put_resp_content_type("application/json")
      @resp_body = BunnyKit::Json.encode(value)
      self
    end

    def redirect(to : String) : Conn
      @status = 302
      put_resp_header("location", to)
      @resp_body = ""
      halt
    end

    def halt : Conn
      @halted = true
      self
    end
  end
end
