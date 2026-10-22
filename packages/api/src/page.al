# Offset pagination from ?page=&per_page= (per_page capped at 100).
module BunnyApi
  class Page
    MAX_PER_PAGE = 100
    getter entries : List(Object)
    getter page : Int32
    getter per_page : Int32
    getter total : Int32

    def initialize(@entries : List(Object), @page : Int32, @per_page : Int32, @total : Int32)
    end

    def total_pages : Int32
      return 1 if @total == 0
      (@total + @per_page - 1) / @per_page
    end

    def self.int_param(c : Bunny::Conn, name : String, dflt : Int32) : Int32
      n = 0
      return dflt unless Int32.TryParse(c.param(name), out n)
      n
    end

    def self.from(c : Bunny::Conn, all : List(Object)) : Page
      page = Math.max(1, int_param(c, "page", 1))
      per = Math.min(MAX_PER_PAGE, Math.max(1, int_param(c, "per_page", 20)))
      start = Math.min(all.size, (page - 1) * per)
      count = Math.min(per, all.size - start)
      Page.new(all.GetRange(start, count), page, per, all.size)
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
