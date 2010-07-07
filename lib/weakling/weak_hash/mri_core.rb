module Weakling
  class WeakHash
    module Core
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

      def each
        @key_to_value.each do |key_id, value_id|
          begin
            value = ObjectSpace._id2ref(value_id)
            key = ObjectSpace._id2ref(key_id)

            yield [key,value]
          rescue RangeError
          end
        end
      end
    end
  end
end
