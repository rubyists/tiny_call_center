# Copyright (c) 2008-2009 The Rubyists, LLC (effortless systems) <rubyists@rubyists.com>
# Distributed under the terms of the MIT license.
# The full text can be found in the LICENSE file included with this software
#
require "pathname"
task :legal do
  license = Pathname("LICENSE")
  license.open("w+") do |f|
    f.puts PROJECT_COPYRIGHT
  end unless license.file? and license.read == PROJECT_COPYRIGHT
  doc = Pathname("doc/LEGAL")
  doc.open("w+") do |f|
    f.puts "LICENSE"
  end unless doc.file?
end

desc "add copyright summary to all .rb files in the distribution"
task :copyright => [:legal] do
  doc = Pathname("doc/LEGAL")
  ignore = doc.readlines.
    select { |line| line.strip!; Pathname(line).file? }.
    map { |file| Pathname(file).expand_path }

  puts "adding copyright summary to files that don't have it currently"
  puts PROJECT_COPYRIGHT_SUMMARY
  puts

  (Pathname.glob('{controller,model,app,lib,test,spec,migrations}/**/*{.rb}') + 
   Pathname.glob("tasks/*.rake") +
   Pathname.glob("Rakefile")).each do |file|
    next if ignore.include? file.expand_path
    lines = file.readlines.map{ |l| l.chomp }
    unless lines.first(PROJECT_COPYRIGHT_SUMMARY.size) == PROJECT_COPYRIGHT_SUMMARY
      oldlines = file.readlines
      file.open("w+") { |f| f.puts PROJECT_COPYRIGHT_SUMMARY + oldlines }
    end
  end
end
