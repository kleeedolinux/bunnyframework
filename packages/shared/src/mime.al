# Content types by file extension.
module BunnyKit
  module Mime
    def self.for_path(path : String) : String
      dot = path.LastIndexOf(".")
      return "application/octet-stream" if dot < 0
      for_ext(path.Substring(dot + 1).ToLowerInvariant)
    end

    def self.for_ext(ext : String) : String
      case ext
      when "html", "htm" then "text/html; charset=utf-8"
      when "css" then "text/css; charset=utf-8"
      when "js", "mjs" then "application/javascript"
      when "json" then "application/json"
      when "txt" then "text/plain; charset=utf-8"
      when "svg" then "image/svg+xml"
      when "png" then "image/png"
      when "jpg", "jpeg" then "image/jpeg"
      when "gif" then "image/gif"
      when "webp" then "image/webp"
      when "ico" then "image/x-icon"
      when "woff2" then "font/woff2"
      when "wasm" then "application/wasm"
      else "application/octet-stream"
      end
    end
  end
end
