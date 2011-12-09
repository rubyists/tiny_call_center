# Copyright (c) 2008-2011 The Rubyists, LLC (effortless systems) <rubyists@rubyists.com>
# Distributed under the terms of the MIT license.
# The full text can be found in the LICENSE file included with this software

require 'rake'
require 'rake/clean'
require 'rubygems/package_task'
require 'time'
require 'date'

PROJECT_SPECS = FileList['spec/*/**/*.rb']
PROJECT_MODULE = 'FsrCallcenter'
PROJECT_README = 'README'
PROJECT_COPYRIGHT_SUMMARY = [
 "# Copyright (c) 2008-#{Time.now.year} The Rubyists, LLC (effortless systems) <rubyists@rubyists.com>",
 "# Distributed under the terms of the MIT license.",
 "# The full text can be found in the LICENSE file included with this software",
 "#",
]
PROJECT_COPYRIGHT = PROJECT_COPYRIGHT_SUMMARY + [
 "# Permission is hereby granted, free of charge, to any person obtaining a copy",
 '# of this software and associated documentation files (the "Software"), to deal',
 "# in the Software without restriction, including without limitation the rights",
 "# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell",
 "# copies of the Software, and to permit persons to whom the Software is",
 "# furnished to do so, subject to the following conditions:",
 "#",
 "# The above copyright notice and this permission notice shall be included in",
 "# all copies or substantial portions of the Software.",
 "#",
 '# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR',
 "# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,",
 "# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE",
 "# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER",
 "# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,",
 "# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN",
 "# THE SOFTWARE."
]

# To release the monthly version do:
# $ PROJECT_VERSION=2009.03 rake release
IGNORE_FILES = [/\.gitignore/]

GEMSPEC = Gem::Specification.new{|s|
  s.name         = 'fxc'
  s.author       = "The Rubyists, LLC"
  s.summary      = "The FsrCallcenter library, by The Rubyists, LLC"
  s.description  = "The FsrCallcenter library, by The Rubyists, LLC"
  s.email        = 'rubyists@rubyists.com'
  s.homepage     = 'http://code.rubyists.com/projects/fsr_callcenter'
  s.platform     = Gem::Platform::RUBY
  s.version      = (ENV['PROJECT_VERSION'] || (begin;Object.const_get(PROJECT_MODULE)::VERSION;rescue;Date.today.strftime("%Y.%m.%d");end))
  s.files        = `git ls-files`.split("\n").sort.reject { |f| IGNORE_FILES.detect { |exp| f.match(exp)  } }
  s.has_rdoc     = true
  s.require_path = 'lib'
  

  s.post_install_message = <<MESSAGE.strip
============================================================

Thank you for installing Fxc!

============================================================
MESSAGE
}

Dir['tasks/*.rake'].each{|f| import(f) }

task :default => [:bacon]

CLEAN.include %w[
  **/.*.sw?
  *.gem
  .config
  **/*~
  **/{data.db,cache.yaml}
  *.yaml
  pkg
  rdoc
  ydoc
  *coverage*
]
