# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{weakling}
  s.version = "0.1.6"
  s.authors = ["Charles Oliver Nutter", "Marcin Raczkowski"]
  s.date = Time.now.strftime('%Y-%m-%d')
  s.description = "A modified WeakRef impl for JRuby plus some weakref-related tools"
  s.email = ["headius@headius.com", "marcin.raczkowski@gmail.com"]
  s.files = Dir['{lib,ext,examples,test}/**/*'] + Dir['{*.txt,*.gemspec,Rakefile}']
  s.homepage = "http://github.com/headius/weakling"
  s.require_paths = ["lib"]
  s.summary = "A modified WeakRef impl for JRuby plus some weakref-related tools"
  s.test_files = Dir["test/test*.rb"]
  s.platform = Gem::Platform::RUBY
end
