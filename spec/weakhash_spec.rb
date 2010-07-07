require 'weakling'
require 'jruby'

def force_gc_cleanup
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
  sleep 0.2 # Give GC a little time to do the magick
end

describe Weakling::WeakHash do
  before(:each) do
    @weak_hash = Weakling::WeakHash.new
    @str = "A";
    @obj = Object.new
    @sym = :foo
    @fix = 666
  end

  it "allows us to assign value, and return assigned value" do
    a = @str; b = @obj
    (@weak_hash[a] = b).should == b
  end

  it "should allow us to assign and read value" do
    a = @str; b = @obj
    (@weak_hash[a] = b).should == b
    @weak_hash[a].should == b
  end

  it "should use object_id to identify objects" do
    a = Object.new
    @weak_hash[a] = "b"
    @weak_hash[a.dup].should be_nil
  end

  it "doesn't leak memory" do
    initial_memory_usage = `ps -o rss= -p #{$$}`.to_i

    1000.times do |x|
      @weak_hash[Object.new] = "&"*10000
      @weak_hash[x] = "&"*10000
    end

    force_gc_cleanup
    @weak_hash._cleanup if @weak_hash.respond_to?(:_cleanup)
    
    memory_usage = `ps -o rss= -p #{$$}`.to_i

    memory_usage.should < initial_memory_usage * 1.5
  end
end

