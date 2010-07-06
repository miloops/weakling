require 'rubygems'
require 'set'
begin
  require "weakling"
rescue LoadError
end
require 'thread'

module Weakling
  class WeakHash
    if defined?(RUBY_ENGINE) && RUBY_ENGINE == 'jruby'
      module JRubyCore
        class IdWeakRef < Weakling::WeakRef
          attr_accessor :id
          def initialize(obj, queue)
            super(obj, queue)
            @id = obj.__id__
          end
        end

        def initialize
          @key_to_value = Hash.new
          @value_to_keys = Hash.new{|hash, key| hash[key] = Hash.new }
        
          @key_queue = Weakling::RefQueue.new
          @value_queue = Weakling::RefQueue.new
        end

        def [](key)
          _cleanup
          value_ref = @key_to_value[key.object_id]
          value_ref ? value_ref.get : nil
        rescue RefError
          nil
        end

        def []=(key, value)
          _cleanup
          key_ref = IdWeakRef.new(key, @key_queue)
          value_ref = IdWeakRef.new(value, @value_queue)

          if old_value_ref = @key_to_value[key_ref.id]
            @value_to_keys[old_value_ref.id].delete(key_ref.id)
          end
        
          @key_to_value[key_ref.id] = value_ref
          @value_to_keys[value_ref.id][key_ref.id] = key_ref

          value
        end

        def _cleanup
          while ref = @key_queue.poll
            value_ref = @key_to_value.delete(ref.id)
            @value_to_keys[value_ref.id].delete(ref.id)
          end
          while ref = @value_queue.poll
            @value_to_keys.delete(ref.id).each{|k| @key_to_value.delete(k) }
          end
        end
      end
    else
      module MRICore
        def initialize
          @key_to_value = Hash.new
          @value_to_keys = Hash.new{|hash, key| hash[key] = Hash.new }

          @reclaim_value = lambda{|v_id| @value_to_keys.delete(v_id).each{|k| @key_to_value.delete(k)}}
          @reclaim_key = lambda{|k_id| v_id = @key_to_value.delete(k_id); @value_to_keys[v_id].delete(k_id) }
        end

        def [](key)
          v_id = @key_to_value[key.object_id]
          return v_id ? ObjectSpace._id2ref(v_id) : nil
        rescue RangeError
          nil
        end

        def []=(key, value)
          if v_id = @key_to_value[key.object_id]
            @value_to_keys[v_id].delete(key_object_id)
          end

          @key_to_value[key.object_id] = value.object_id

          unless [TrueClass, FalseClass, NilClass, Fixnum, Symbol].include?(value.class)
            @value_to_keys[value.object_id][key.object_id]=true
            ObjectSpace.define_finalizer(value, @reclaim_value)
          end
          unless [TrueClass, FalseClass, NilClass, Fixnum, Symbol].include?(key.class)
            ObjectSpace.define_finalizer(key, @reclaim_key)
          end

          value
        end

        def method_missing(name, *args, &block)
          @key_to_value.send(name, *args, &block)
        end
      end
    end

    if defined?(RUBY_ENGINE) && RUBY_ENGINE == 'jruby'
      Core = JRubyCore
    else
      Core = MRICore
    end

    include Core
  end

  class SynchronizedWeakHash < Mutex
    include WeakHash::Core
  
    def [](key)
      synchronize do
        super
      end
    end
  
    def []=(key, value)
      synchronize do
        super
      end
    end
  end
end

class Test
  attr_accessor :foo, :bar, :baz
end

w = Weakling::WeakHash.new

def force_cleanup
  if defined? RUBY_ENGINE && RUBY_ENGINE == 'jruby'
    begin
      require 'java'
      java.lang.System.gc
    rescue
      JRuby.gc
    end
  else
    GC.start
  end
end

a = "a"
100.times {|x|
  y = x + 1
  #w[Object.new] = Test.new
  w[Object.new] = 1#"Test.new"
}

10.times{ force_cleanup }

w._cleanup rescue nil
puts "\n"
p w
