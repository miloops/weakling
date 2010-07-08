require 'weakling'
if defined?(RUBY_ENGINE) && RUBY_ENGINE == 'jruby'
  require 'jruby'
end

def force_gc_cleanup
  if defined?(RUBY_ENGINE) && RUBY_ENGINE == 'jruby'
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

# Looks like there's a strange bug in MRI 1.8.7 and 1.9.1 last value assigned to hash
# Is somehow bound and not collected - I'm not sure why, it looks like scoping
# issue with blocks and enumerators (adding nil at the end of the block solved
# it for 1.8.7 but not 1.9.1.
#
# Interesingly both jRuby and REE don't exhibit this issue.
# So for test purposes we're ignoring that one item in hash
Spec::Matchers.define :be_almost_empty do
  match do |actual|
    actual._clean? ||
      %w{key_to_value value_to_keys hash_map rev_hash_map}.all?{|k|
        actual.instance_variable_get("@#{k}").length <= 1
      }
  end

  failure_message_for_should do |actual|
    "expected that WeakHash would be empty. Instead it has following elements: \n  "+
      actual.map{|k,v| "#{k.inspect} => #{v.inspect}"}.join("\n  ")+
      "\nvariables: \n  "+
      %w{key_to_value value_to_keys hash_map rev_hash_map}.map{|k| k+": "+actual.instance_variable_get("@#{k}").inspect }.join("\n  ")
  end

  failure_message_for_should_not do |actual|
    "expected that WeakHash would not be empty."
  end

  description do
    "be almost empty."
  end

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

  {
    Object => String,
    String => 1,
    String => :foo
  }.each_pair do |key,value|
    it "should properly collect #{key} => #{value} pair" do
      (1..10).each{
        k = key.is_a?(Class) ? key.new : key
        v = value.is_a?(Class) ? value.new : value
        @weak_hash[k] = v

        nil
      }
      
      force_gc_cleanup
      @weak_hash._cleanup if @weak_hash.respond_to?(:_cleanup)
      
      @weak_hash.should be_almost_empty
    end
  end

  it "should properly collect Fixnum => String pair" do
    (1..20).each{ |x|
      @weak_hash[x] = "Foo"*5

      nil
    }

    force_gc_cleanup
    @weak_hash._cleanup if @weak_hash.respond_to?(:_cleanup)

    @weak_hash.should be_almost_empty
  end

  it "Should properly collect multiple keys with the same value" do
    (1..10).each do |x|
      @weak_hash["a"*x] = true
      @weak_hash["b"*x] = true
      @weak_hash["c"*x] = true
      @weak_hash["a"*x] = false
      @weak_hash["d"*x] = false

      nil
    end
    
    force_gc_cleanup
    @weak_hash._cleanup if @weak_hash.respond_to?(:_cleanup)

    @weak_hash.should be_almost_empty
  end

  it "doesn't leak memory" do
    (1..100).each do |x|
      @weak_hash[Object.new] = "&"*10000 # Both values collectable
      @weak_hash[x] = "&"*10000          # only value collectable
      @weak_hash[x.to_s] = :foo          # only key collectable + multiple keys with same value

      nil
    end

    force_gc_cleanup
    @weak_hash._cleanup if @weak_hash.respond_to?(:_cleanup)

    @weak_hash.should be_almost_empty
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

