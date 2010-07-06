require 'weakling'
require 'jruby'

describe Weakling::WeakHash do
  before(:each) do
    @weak_hash = Weakling::WeakHash.new
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

