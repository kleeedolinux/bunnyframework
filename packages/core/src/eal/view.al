# View: base class of every compiled .html.eal template, plus the name -> view registry.
module Bunny
  abstract class View
    getter name : String
    getter statics : Array(String)

    def initialize(@name : String, @statics : Array(String))
    end

    abstract def write(a : Hash(String, Object), out : EalOut) : Nil

    def render(a : Hash(String, Object)) : String
      out = EalOut.new(false, @statics)
      write(a, out)
      out.result
    end

    def dynamics(a : Hash(String, Object)) : List(String)
      out = EalOut.new(true, @statics)
      write(a, out)
      out.dyns
    end

    def self.fetch(a : Hash(String, Object), key : String, view : String) : Object
      unless a.has_key?(key)
        raise System.Collections.Generic.KeyNotFoundException.new("template #{view} needs assign '#{key}'")
      end
      a[key]
    end
  end

  module Views
    REGISTRY = Hash(String, View).new

    def self.register(v : View) : Nil
      REGISTRY[v.name] = v
    end

    def self.has?(name : String) : Bool
      REGISTRY.has_key?(name)
    end

    def self.fetch(name : String) : View
      unless REGISTRY.has_key?(name)
        raise System.Collections.Generic.KeyNotFoundException.new("no template #{name}.html.eal (run `bunny compile`)")
      end
      REGISTRY[name]
    end
  end
end
