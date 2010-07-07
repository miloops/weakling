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
  # 
  #
  class WeakHash
    include Core
    include Enumerable
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