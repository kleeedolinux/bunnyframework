# Pure pagination arithmetic (no dependencies, so `alice prove` can check it alone).
module BunnyApi
  module Kernels
    pure def self.max_per_page : Int32
      100
    end

    pure def self.clamp(x : Int32, lo : Int32, hi : Int32) : Int32
      return lo if x < lo
      return hi if x > hi
      x
    end

    pure def self.page(requested : Int32) : Int32
      requested < 1 ? 1 : requested
    end

    pure def self.per_page(requested : Int32) : Int32
      clamp(requested, 1, max_per_page)
    end

    # First entry index of `page` (clamped into [0, total]).
    pure def self.window_start(total : Int32, req_page : Int32, req_per : Int32) : Int32
      p = page(req_page)
      q = per_page(req_per)
      return total if p - 1 > total / q
      clamp((p - 1) * q, 0, total)
    end

    pure def self.window_count(total : Int32, req_page : Int32, req_per : Int32) : Int32
      start = window_start(total, req_page, req_per)
      q = per_page(req_per)
      total - start < q ? total - start : q
    end

    pure def self.total_pages(total : Int32, req_per : Int32) : Int32
      q = per_page(req_per)
      return 1 if total == 0
      (total + q - 1) / q
    end
  end
end
