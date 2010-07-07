require 'weakling'
if defined? RUBY_ENGINE && RUBY_ENGINE == 'jruby'
  require 'jruby'
end

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
  sleep 0.5 # Give GC a little time to do the magick
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

  it "should find objects that have same hash" do
    @weak_hash["a"] = "b"
    @weak_hash["a"].should == "b"
  end

  it "should hold mappings" do
    result = (1..10).map do |x|
      @weak_hash[x] = "x" * x
      [x, "x"*x]
    end

    @weak_hash.to_a.sort.should == result
  end

  it "should allow iteration" do
    result = {}
    (1..10).map do |x|
      @weak_hash[x] = "x" * x
      result[x] = "x"*x
    end

    @weak_hash.each do |k,v|
      result[k].should == v
    end
  end

  it "should weakly reference the objects" do
    ary = (1..10).to_a.map {|o| o = Object.new; o}
    ary.each{|o| @weak_hash[o] = "x"; }
    ary = nil

    force_gc_cleanup
    
    @weak_hash.to_a.should be_empty
  end

  it "doesn't leak memory" do
    100.times do |x|
      @weak_hash[Object.new] = "&"*10000 # Both values collectable
      @weak_hash[x] = "&"*10000          # only value collectable
      @weak_hash[x.to_s] = :foo          # only key collectable + multiple keys with same value
    end

    force_gc_cleanup
    @weak_hash._cleanup if @weak_hash.respond_to?(:_cleanup)
    unless @weak_hash._clean?
      p @weak_hash
    end
    @weak_hash._clean?.should be_true
  end

#  Long running test, takes a long time and basically duplicates previous ones.
#  You can try to run it when you _realy_ want to check if memory isn't leaked.
#  Doesn't force GC - assumes GC passes will be run automatically.
#
#  it "realy doesn't leak memory" do
#    initial_memory_usage = `ps -o rss= -p #{$$}`.to_i
#    10000.times do |x|
#      @weak_hash[Object.new] = "&"*10000 # Both values collectable
#      @weak_hash[x] = "&"*10000          # only value collectable
#      @weak_hash[x.to_s] = :foo          # only key collectable + multiple keys with same value
#    end
#
#    memory_usage = `ps -o rss= -p #{$$}`.to_i
#
#    memory_usage.should < initial_memory_usage * 1.5
#  end
end

