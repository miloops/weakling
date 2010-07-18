require "weakling"

module Weakling
  class WeakHash
    module Core
      class IdWeakRef < Weakling::WeakRef
        attr_accessor :id
        def initialize(obj, queue)
          super(obj, queue)
          @id = obj.object_id
        end
      end

      def initialize
        # Queues for hash cleaning
        @key_queue = Weakling::RefQueue.new
        @value_queue = Weakling::RefQueue.new

        @reclaim_value = lambda do |v_id|
          if @value_to_keys.has_key?(v_id)
            @value_to_keys.delete(v_id).each{|k_id, _| @reclaim_key.call(k_id)}
          end
        end

        @reclaim_key = lambda do |k_id|
          return unless v_ref = @key_to_value.delete(k_id)
          v_id = v_ref.id
          @value_to_keys[v_id].delete(k_id)
          @value_to_keys.delete(v_id) if @value_to_keys[v_id].empty?

          hash = @rev_hash_map.delete(k_id)
          @hash_map[hash].delete(k_id)
          @hash_map.delete(hash) if @hash_map[hash].empty?
        end
      end

      def [](key)
        _cleanup
        value_ref = @key_to_value[key.object_id]

        # Tries to find a value reference by _hash_value_
        if !value_ref && @hash_map.has_key?(key.hash)
          key_id = nil
          @hash_map[key.hash].any? do |k_id, key_ref|
            hkey = key_ref.get rescue nil
            key_id = k_id if hkey == key
          end
          value_ref = @key_to_value[key_id]
        end

        value_ref ? value_ref.get : nil
      rescue RefError
        nil
      end

      def []=(key, value)
        # If key was already occupied by another value, we must first remove old key
        delete(key)

        _cleanup
        key_ref = IdWeakRef.new(key, @key_queue)
        value_ref = IdWeakRef.new(value, @value_queue)

        # Assigns value reference to key, and vice-versa
        @key_to_value[key_ref.id] = value_ref
        @value_to_keys[value_ref.id][key_ref.id] = key_ref

        # Save also hash value
        @hash_map[key.hash][key_ref.id] = key_ref
        @rev_hash_map[key_ref.id] = key.hash

        value
      end

      def delete(key)
        if @hash_map.has_key?(key.hash)
          @hash_map[key.hash].any? do |k_id, key_ref|
            hkey = key_ref.get rescue nil
            @reclaim_key.call(k_id) if hkey == key
          end
        end

        nil
      end

      def each
        _cleanup

        @key_to_value.each do |key_id, value_ref|
          begin
            value = value_ref.get
            key_ref = @value_to_keys[value_ref.id][key_id]
            key = key_ref.get

            yield [key,value]
          rescue RefError
          end
        end

        self
      end

      def _cleanup
        while ref = @key_queue.poll # Key was collected
          @reclaim_key.call(ref.id)
        end
        while ref = @value_queue.poll
          @reclaim_value.call(ref.id)
        end
      end
    end
  end
end
