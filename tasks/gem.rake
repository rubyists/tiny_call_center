# Copyright (c) 2008-2011 The Rubyists, LLC (effortless systems) <rubyists@rubyists.com>
# Distributed under the terms of the MIT license.
# The full text can be found in the LICENSE file included with this software

desc "make a gemspec"
task :gemspec => [:manifest, :changelog, :authors] do
  gemspec_file = "#{GEMSPEC.name}.gemspec"
  File.open(gemspec_file, 'w+'){|gs| gs.puts(GEMSPEC.to_ruby) }
end

desc "package and install from gemspec"
task :install => [:gemspec] do
  sh "gem build #{GEMSPEC.name}.gemspec"
  sh "gem install #{GEMSPEC.name}-#{GEMSPEC.version}.gem"
end

desc "uninstall the gem"
task :uninstall => [:clean] do
  sh %{gem uninstall -x #{GEMSPEC.name}}
end

Gem::PackageTask.new(GEMSPEC) do |pkg|
    pkg.need_tar = true
end
