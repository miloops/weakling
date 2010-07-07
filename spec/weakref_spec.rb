if defined?(RUBY_ENGINE) && RUBY_ENGINE == 'jruby'

require 'weakling'
require 'jruby'

def force_gc_cleanup
  require 'java'
  java.lang.System.gc
rescue
  JRuby.gc
ensure
  sleep 0.2 # Give GC a little time to do the magick
end

describe Weakling::WeakRef do
  it "holds a reference to an object" do
    o = Object.new
    w = Weakling::WeakRef.new(o)
    w.get.should equal(o)
  end

  it "weakly references the contained object" do
    o = Object.new
    w = Weakling::WeakRef.new(o)
    o = nil
    5.times {JRuby.gc}

    lambda {w.get}.should raise_error RefError
    w.weakref_alive?.should == false
  end

  it "accepts a RefQueue for reporting collected refs" do
    o1 = Object.new
    o2 = Object.new
    r = Weakling::RefQueue.new
    w1 = Weakling::WeakRef.new(o1, r)
    w2 = Weakling::WeakRef.new(o2, r)
    
    r.poll.should == nil
    r.remove(50).should == nil

    o1 = nil
    force_gc_cleanup

    r.poll.should == w1

    o2 = nil
    force_gc_cleanup
    
    r.remove.should == w2
  end
end

end
