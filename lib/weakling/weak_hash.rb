require 'thread'
if defined?(RUBY_ENGINE) && RUBY_ENGINE == 'jruby'
  require File.join(File.dirname(__FILE__), 'weak_hash', 'jruby_core')
else
  require File.join(File.dirname(__FILE__), 'weak_hash', 'mri_core')
end

module Weakling
  # *WeakHash* implements a simple hash where *both* key and value are weakly referenced.
  # There are currently two separate implementations for JRuby and MRI -
  # that implement the same interface with 3 methods:
  # #[] #[]= and #each. _Enumerable_ module is included for convience.
  #
  # WeakHash lookup and store is O(1) in most cases, unfortunatelly it might
  # degrade to O(n) if you put to much keys with same hash into it
  # (side effect of trivial conflict resolution)/
  #
  # *Warning* WeakHash _might_ leak memory if both key and value are so called
  # _immidiate_ values - so in MRI [TrueClass, FalseClass, NilClass, Fixnum, Symbol]
  # Since GC doesn't collect them, they will never be removed from WeakHash.
  class WeakHash
    include Core
    include Enumerable

    def initialize
      super
      
      @key_to_value = Hash.new
      @value_to_keys = Hash.new{|hash, key| hash[key] = Hash.new }

      @hash_map = Hash.new{|hash, key| hash[key] = Hash.new }
      @rev_hash_map = Hash.new
    end

    def _clean?
      @key_to_value.empty? &&
        @value_to_keys.empty? &&
        @hash_map.empty? &&
        @rev_hash_map.empty?
    end

    def clear
      [@key_to_value, @value_to_keys, @hash_map, @rev_hash_map].each{|h| h.clear}

      self
    end
  end

  class SynchronizedWeakHash < Mutex
    include WeakHash::Core
    include Enumerable
  
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