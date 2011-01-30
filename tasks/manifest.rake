# Copyright (c) 2008-2009 The Rubyists, LLC (effortless systems) <rubyists@rubyists.com>
# Distributed under the terms of the MIT license.
# The full text can be found in the LICENSE file included with this software
#
desc 'update manifest'
task :manifest do
  File.open('MANIFEST', 'w+'){|io| io.puts(*GEMSPEC.files) }
end
