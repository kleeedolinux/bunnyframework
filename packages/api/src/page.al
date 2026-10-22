# Offset pagination from ?page=&per_page= (per_page capped at 100). Arithmetic in Kernels, proven in RULES.al.
module BunnyApi
  class Page
    getter entries : List(Object)
    getter page : Int32
    getter per_page : Int32
    getter total : Int32

    def initialize(@entries : List(Object), @page : Int32, @per_page : Int32, @total : Int32)
    end

    def total_pages : Int32
      Kernels.total_pages(@total, @per_page)
    end

    def self.int_param(c : Bunny::Conn, name : String, dflt : Int32) : Int32
      n = 0
      return dflt unless Int32.TryParse(c.param(name), out n)
      n
    end

    def self.from(c : Bunny::Conn, all : List(Object)) : Page
      req_page = int_param(c, "page", 1)
      req_per = int_param(c, "per_page", 20)
      start = Kernels.window_start(all.size, req_page, req_per)
      count = Kernels.window_count(all.size, req_page, req_per)
      Page.new(all.GetRange(start, count), Kernels.page(req_page), Kernels.per_page(req_per), all.size)
    end

    def to_h : Hash(String, Object)
      meta = Hash(String, Object).new
      meta["page"] = @page
      meta["per_page"] = @per_page
      meta["total"] = @total
      meta["total_pages"] = total_pages
      h = Hash(String, Object).new
      h["data"] = @entries
      h["meta"] = meta
      h
    end
  end
end
