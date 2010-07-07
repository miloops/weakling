require 'weakling'
require 'jruby'

def force_cleanup
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
      w[x] = Test.new
      w[x-1] = Object.new
      w[:bat] = :foo
      w[Object.new] = "&"*1000
      w["FOOO"*10000] = x+1
      w[:foo] = "BAR"
    end

    w.clear
    5.times{ GC.start }

    memory_usage = `ps -o rss= -p #{$$}`.to_i

    memory_usage.should < initial_memory_usage * 1.5
  end
end

