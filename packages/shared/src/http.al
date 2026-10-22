# HTTP wire primitives: status reason phrases.
# Written with `if`, not `case`: Alice infers purity for it, so RULES.al can prove it.
module BunnyKit
  module Http
    pure def self.reason(code : Int32) : String
      klass = code / 100
      if klass == 1
        return "Continue" if code == 100
        return "Switching Protocols" if code == 101
      elsif klass == 2
        return "OK" if code == 200
        return "Created" if code == 201
        return "Accepted" if code == 202
        return "No Content" if code == 204
      elsif klass == 3
        return "Moved Permanently" if code == 301
        return "Found" if code == 302
        return "See Other" if code == 303
        return "Not Modified" if code == 304
        return "Temporary Redirect" if code == 307
        return "Permanent Redirect" if code == 308
      elsif klass == 4
        return "Bad Request" if code == 400
        return "Unauthorized" if code == 401
        return "Forbidden" if code == 403
        return "Not Found" if code == 404
        return "Method Not Allowed" if code == 405
        return "Not Acceptable" if code == 406
        return "Conflict" if code == 409
        return "Payload Too Large" if code == 413
        return "Unsupported Media Type" if code == 415
        return "Unprocessable Entity" if code == 422
        return "Too Many Requests" if code == 429
      elsif klass == 5
        return "Internal Server Error" if code == 500
        return "Not Implemented" if code == 501
        return "Bad Gateway" if code == 502
        return "Service Unavailable" if code == 503
      end
      "Unknown"
    end
  end
end
