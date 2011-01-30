# Copyright (c) 2008-2009 The Rubyists, LLC (effortless systems) <rubyists@rubyists.com>
# Distributed under the terms of the MIT license.
# The full text can be found in the LICENSE file included with this software
#
desc "update version.rb"
task :reversion do
  File.open("lib/#{GEMSPEC.name}/version.rb", 'w+') do |file|
    file.puts("module #{PROJECT_MODULE}")
    file.puts('  VERSION = %p' % GEMSPEC.version.to_s)
    file.puts('end')
  end
end
