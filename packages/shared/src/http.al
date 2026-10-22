# HTTP wire primitives: status reason phrases.
module BunnyKit
  module Http
    def self.reason(code : Int32) : String
      case code
      when 100 then "Continue"
      when 101 then "Switching Protocols"
      when 200 then "OK"
      when 201 then "Created"
      when 202 then "Accepted"
      when 204 then "No Content"
      when 301 then "Moved Permanently"
      when 302 then "Found"
      when 303 then "See Other"
      when 304 then "Not Modified"
      when 307 then "Temporary Redirect"
      when 308 then "Permanent Redirect"
      when 400 then "Bad Request"
      when 401 then "Unauthorized"
      when 403 then "Forbidden"
      when 404 then "Not Found"
      when 405 then "Method Not Allowed"
      when 406 then "Not Acceptable"
      when 409 then "Conflict"
      when 413 then "Payload Too Large"
      when 415 then "Unsupported Media Type"
      when 422 then "Unprocessable Entity"
      when 429 then "Too Many Requests"
      when 500 then "Internal Server Error"
      when 501 then "Not Implemented"
      when 502 then "Bad Gateway"
      when 503 then "Service Unavailable"
      else "Unknown"
      end
    end
  end
end
