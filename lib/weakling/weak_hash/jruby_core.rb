require "weakling"

module Weakling
  class WeakHash
    module Core
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

        @hash_map = Hash.new{|hash, key| hash[key] = Hash.new }
        @rev_hash_map = Hash.new
      end

      def [](key)
        _cleanup
        value_ref = @key_to_value[key.object_id]

        if !value_ref && @hash_map[key.hash]
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
        _cleanup
        key_ref = IdWeakRef.new(key, @key_queue)
        value_ref = IdWeakRef.new(value, @value_queue)

        if old_value_ref = @key_to_value[key_ref.id]
          @value_to_keys[old_value_ref.id].delete(key_ref.id)
        end

        @key_to_value[key_ref.id] = value_ref
        @value_to_keys[value_ref.id][key_ref.id] = key_ref

        @hash_map[key.hash][key_ref.id] = key_ref
        @rev_hash_map[key_ref.id] = key.hash

        value
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
      end

      def _cleanup
        while ref = @key_queue.poll
          value_ref = @key_to_value.delete(ref.id)
          @value_to_keys[value_ref.id].delete(ref.id)
          @hash_map[@rev_hash_map.delete(ref.id)].delete(ref.id)
        end
        while ref = @value_queue.poll
          @value_to_keys.delete(ref.id).each{|k| @key_to_value.delete(k) }
        end
      end
    end
  end
end
