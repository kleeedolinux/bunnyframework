# Router: routes compiled into a segment tree; scopes add prefixes and pipelines.
module Bunny
  class Route
    getter verb : String
    getter pattern : String
    getter handler : Func(Conn, Conn)
    getter pipes : List(String)

    def initialize(@verb : String, @pattern : String, @handler : Func(Conn, Conn), @pipes : List(String))
    end
  end

  class RouteNode
    getter statics : Hash(String, RouteNode) = Hash(String, RouteNode).new
    property param_name : String = ""
    property param_child : RouteNode? = nil
    property wildcard_name : String = ""
    getter wildcard_routes : Hash(String, Route) = Hash(String, Route).new
    getter routes : Hash(String, Route) = Hash(String, Route).new
  end

  class Router
    getter pipelines : Hash(String, Pipeline) = Hash(String, Pipeline).new
    getter all_routes : List(Route) = List(Route).new
    @root : RouteNode = RouteNode.new
    @prefix : String = ""
    @pipes : List(String) = List(String).new

    def pipeline(name : String, &blk : Pipeline -> Nil) : Nil
      p = Pipeline.new
      blk.call(p)
      @pipelines[name] = p
    end

    def scope(prefix : String, pipes : Array(String), &blk : Router -> Nil) : Nil
      saved_prefix = @prefix
      saved_pipes = @pipes
      @prefix = join_path(@prefix, prefix)
      next_pipes = List(String).new(saved_pipes)
      for p in pipes
        next_pipes << p
      end
      @pipes = next_pipes
      blk.call(self)
      @prefix = saved_prefix
      @pipes = saved_pipes
    end

    def scope(prefix : String, &blk : Router -> Nil) : Nil
      scope(prefix, Array(String).new(0), blk)
    end

    def get(path : String, h : Func(Conn, Conn)) : Router
      add("GET", path, h)
    end

    def post(path : String, h : Func(Conn, Conn)) : Router
      add("POST", path, h)
    end

    def put(path : String, h : Func(Conn, Conn)) : Router
      add("PUT", path, h)
    end

    def patch(path : String, h : Func(Conn, Conn)) : Router
      add("PATCH", path, h)
    end

    def delete(path : String, h : Func(Conn, Conn)) : Router
      add("DELETE", path, h)
    end

    def add(verb : String, path : String, h : Func(Conn, Conn)) : Router
      full = join_path(@prefix, path)
      route = Route.new(verb, full, h, List(String).new(@pipes))
      @all_routes << route
      node = @root
      for seg in Router.segments(full)
        if seg.StartsWith(":")
          child = node.param_child
          if child.nil?
            fresh = RouteNode.new
            node.param_child = fresh
            node.param_name = seg.Substring(1)
            node = fresh
          else
            node = child.not_nil!
          end
        elsif seg.StartsWith("*")
          node.wildcard_name = seg.Substring(1)
          node.wildcard_routes[verb] = route
          return self
        else
          unless node.statics.has_key?(seg)
            node.statics[seg] = RouteNode.new
          end
          node = node.statics[seg]
        end
      end
      node.routes[verb] = route
      self
    end

    # One line per route: "VERB /pattern".
    def routes : List(String)
      out = List(String).new
      for r in @all_routes
        out << "#{r.verb} #{r.pattern}"
      end
      out
    end

    def dispatch(c : Conn) : Conn
      segs = Router.segments(c.path)
      params = Hash(String, String).new
      found = match(@root, segs, 0, params)
      if found.nil?
        return c.put_status(404).text("Not Found")
      end
      table = found.not_nil!
      unless table.has_key?(c.method)
        allow = String.Join(", ", table.Keys)
        return c.put_status(405).put_resp_header("allow", allow).text("Method Not Allowed")
      end
      route = table[c.method]
      params.each { |k, v| c.path_params[k] = v }
      for name in route.pipes
        c = @pipelines[name].run(c)
        return c if c.halted
      end
      route.handler.Invoke(c)
    end

    # Returns the verb table of the matching node; static beats param beats wildcard.
    def match(node : RouteNode, segs : List(String), i : Int32, params : Hash(String, String)) : Hash(String, Route)?
      if i == segs.size
        return node.routes if node.routes.size > 0
        return nil
      end
      seg = segs[i]
      if node.statics.has_key?(seg)
        r = match(node.statics[seg], segs, i + 1, params)
        return r unless r.nil?
      end
      child = node.param_child
      unless child.nil?
        r = match(child.not_nil!, segs, i + 1, params)
        unless r.nil?
          params[node.param_name] = BunnyKit::Url.decode(seg)
          return r
        end
      end
      if node.wildcard_routes.size > 0
        params[node.wildcard_name] = String.Join("/", segs.GetRange(i, segs.size - i))
        return node.wildcard_routes
      end
      nil
    end

    def self.segments(path : String) : List(String)
      out = List(String).new
      for s in path.split("/")
        out << s if s.size > 0
      end
      out
    end

    def join_path(a : String, b : String) : String
      left = a.TrimEnd('/')
      right = b.TrimStart('/')
      return "/" if left.size == 0 && right.size == 0
      "#{left}/#{right}"
    end
  end
end
