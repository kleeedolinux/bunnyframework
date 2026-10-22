# Data: changesets validate input; a Repo persists records through an adapter.
module Bunny
  class Changeset
    getter changes : Hash(String, String) = Hash(String, String).new
    getter errors : List(String) = List(String).new
    getter error_fields : List(String) = List(String).new

    def self.cast(params : Hash(String, String), permitted : Array(String)) : Changeset
      cs = Changeset.new
      for k in permitted
        cs.changes[k] = params[k] if params.has_key?(k)
      end
      cs
    end

    def valid? : Bool
      @errors.size == 0
    end

    def add_error(field : String, msg : String) : Changeset
      @error_fields << field
      @errors << msg
      self
    end

    def error_for(field : String) : String
      for i in 0...@error_fields.size
        return @errors[i] if @error_fields[i] == field
      end
      ""
    end

    def get(field : String) : String
      @changes.fetch(field, "")
    end

    def validate_required(fields : Array(String)) : Changeset
      for f in fields
        add_error(f, "can't be blank") if get(f).Trim.size == 0
      end
      self
    end

    def validate_length(field : String, min : Int32, max : Int32) : Changeset
      return self unless @changes.has_key?(field)
      n = get(field).size
      if n < min
        add_error(field, "should be at least #{min} character(s)")
      elsif n > max
        add_error(field, "should be at most #{max} character(s)")
      end
      self
    end

    def validate_format(field : String, must_contain : String) : Changeset
      return self unless @changes.has_key?(field)
      add_error(field, "has invalid format") unless get(field).Contains(must_contain)
      self
    end

    def validate_number(field : String, min : Int64, max : Int64) : Changeset
      return self unless @changes.has_key?(field)
      n = 0_i64
      if !Int64.TryParse(get(field), out n)
        add_error(field, "is not a number")
      elsif n < min || n > max
        add_error(field, "must be between #{min} and #{max}")
      end
      self
    end
  end

  class Record
    getter id : Int64
    getter fields : Hash(String, String)

    def initialize(@id : Int64, @fields : Hash(String, String))
    end

    def [](k : String) : String
      return @id.to_s if k == "id"
      @fields.fetch(k, "")
    end

    def to_h : Hash(String, Object)
      h = Hash(String, Object).new
      h["id"] = @id
      @fields.each { |k, v| h[k] = v }
      h
    end
  end

  class RepoResult
    getter record : Record?
    getter changeset : Changeset

    def initialize(@record : Record?, @changeset : Changeset)
    end

    def ok? : Bool
      !@record.nil?
    end
  end

  abstract class Adapter
    abstract def insert(table : String, fields : Hash(String, String)) : Record
    abstract def update(table : String, id : Int64, fields : Hash(String, String)) : Record?
    abstract def get(table : String, id : Int64) : Record?
    abstract def all(table : String) : List(Record)
    abstract def delete(table : String, id : Int64) : Bool
  end

  # Thread-safe in-memory adapter (dev/test).
  class MemoryAdapter < Adapter
    @tables : Hash(String, Hash(Int64, Record)) = Hash(String, Hash(Int64, Record)).new
    @seq : Hash(String, Int64) = Hash(String, Int64).new
    @gate : Object = Object.new

    def rows(name : String) : Hash(Int64, Record)
      @tables[name] = Hash(Int64, Record).new unless @tables.has_key?(name)
      @tables[name]
    end

    def insert(table : String, fields : Hash(String, String)) : Record
      System.Threading.Monitor.Enter(@gate)
      begin
        id = @seq.fetch(table, 0_i64) + 1
        @seq[table] = id
        r = Record.new(id, Hash(String, String).new(fields))
        rows(table)[id] = r
        r
      ensure
        System.Threading.Monitor.Exit(@gate)
      end
    end

    def update(table : String, id : Int64, fields : Hash(String, String)) : Record?
      System.Threading.Monitor.Enter(@gate)
      begin
        t = rows(table)
        return nil unless t.has_key?(id)
        merged = Hash(String, String).new(t[id].fields)
        fields.each { |k, v| merged[k] = v }
        r = Record.new(id, merged)
        t[id] = r
        r
      ensure
        System.Threading.Monitor.Exit(@gate)
      end
    end

    def get(table : String, id : Int64) : Record?
      System.Threading.Monitor.Enter(@gate)
      begin
        t = rows(table)
        return nil unless t.has_key?(id)
        t[id]
      ensure
        System.Threading.Monitor.Exit(@gate)
      end
    end

    def all(table : String) : List(Record)
      System.Threading.Monitor.Enter(@gate)
      begin
        List(Record).new(rows(table).Values)
      ensure
        System.Threading.Monitor.Exit(@gate)
      end
    end

    def delete(table : String, id : Int64) : Bool
      System.Threading.Monitor.Enter(@gate)
      begin
        rows(table).Remove(id)
      ensure
        System.Threading.Monitor.Exit(@gate)
      end
    end
  end

  class Repo
    getter adapter : Adapter

    def initialize(@adapter : Adapter)
    end

    def insert(table : String, cs : Changeset) : RepoResult
      return RepoResult.new(nil, cs) unless cs.valid?
      RepoResult.new(@adapter.insert(table, cs.changes), cs)
    end

    def update(table : String, id : Int64, cs : Changeset) : RepoResult
      return RepoResult.new(nil, cs) unless cs.valid?
      RepoResult.new(@adapter.update(table, id, cs.changes), cs)
    end

    def get(table : String, id : Int64) : Record?
      @adapter.get(table, id)
    end

    def all(table : String) : List(Record)
      @adapter.all(table)
    end

    def where(table : String, field : String, value : String) : List(Record)
      out = List(Record).new
      for r in @adapter.all(table)
        out << r if r[field] == value
      end
      out
    end

    def delete(table : String, id : Int64) : Bool
      @adapter.delete(table, id)
    end
  end
end
