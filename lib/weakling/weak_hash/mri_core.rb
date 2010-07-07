module Weakling
  class WeakHash
    module Core
      def initialize
        @reclaim_value = lambda do |v_id|
          if @value_to_keys.has_key?(v_id)
            @value_to_keys.delete(v_id).each{|k_id, _| @reclaim_key.call(k_id)}
          end
        end

        @reclaim_key = lambda do |k_id|
          v_id = @key_to_value.delete(k_id)
          @value_to_keys[v_id].delete(k_id)
          @value_to_keys.delete(v_id) if @value_to_keys[v_id].empty?

          hash = @rev_hash_map.delete(k_id)
          @hash_map[hash].delete(k_id)
          @hash_map.delete(hash) if @hash_map[hash].empty?
        end
      end

      def [](key)
        v_id = @key_to_value[key.object_id]

        # Tries to find a value reference by _hash_value_
        if !v_id && @hash_map.has_key?(key.hash)
          key_id = nil
          @hash_map[key.hash].keys.any? do |k_id|
            hkey = ObjectSpace._id2ref(k_id) rescue nil
            key_id = k_id if hkey == key
          end
          v_id = @key_to_value[key_id]
        end

        return v_id ? ObjectSpace._id2ref(v_id) : nil
      rescue RangeError
        nil
      end

      def []=(key, value)
        if v_id = @key_to_value[key.object_id]
          @value_to_keys[v_id].delete(key_object_id)
        end

        @key_to_value[key.object_id] = value.object_id
        
        @hash_map[key.hash][key.object_id] = true
        @rev_hash_map[key.object_id] = key.hash

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

        self
      end
    end
  end
end
