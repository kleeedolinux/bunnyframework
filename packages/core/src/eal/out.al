# EalOut: the sink a compiled view writes into.
# Render mode builds the full page; dynamics mode captures only the dynamic slots (LiveView diffs).
module Bunny
  class EalOut
    getter dyns : List(String) = List(String).new
    @sb : System.Text.StringBuilder = System.Text.StringBuilder.new

    def initialize(@dyn_mode : Bool, @statics : Array(String))
    end

    def static(i : Int32) : Nil
      @sb.Append(@statics[i]) unless @dyn_mode
    end

    def open_dyn : Nil
      @sb.Clear if @dyn_mode
    end

    def close_dyn : Nil
      @dyns << @sb.ToString if @dyn_mode
    end

    def text(s : String) : Nil
      @sb.Append(s)
    end

    def esc(v : Object?) : Nil
      return if v.nil?
      @sb.Append(BunnyKit::Html.escape(v.not_nil!.to_s))
    end

    def raw(v : Object?) : Nil
      return if v.nil?
      @sb.Append(v.not_nil!.to_s)
    end

    def result : String
      @sb.ToString
    end
  end
end
