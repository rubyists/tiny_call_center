# Copyright (c) 2008-2009 The Rubyists, LLC (effortless systems) <rubyists@rubyists.com>
# Distributed under the terms of the MIT license.
# The full text can be found in the LICENSE file included with this software
#
# Once git has a fix for the glibc in handling .mailmap and another fix for
# allowing empty mail address to be mapped in .mailmap we won't have to handle
# them manually.

desc 'Update AUTHORS'
task :authors do
  authors = Hash.new(0)

  `git shortlog -nse`.scan(/(\d+)\s(.+)\s<(.*)>$/) do |count, name, email|
    # Examples of mappping, replace with your own or comment this out/delete it
    case name
    when /^(?:bougyman$|TJ Vanderpoel)/
      name, email = "TJ Vanderpoel", "tj@rubyists.com"
    when /^(?:manveru$|Michael Fellinger)/
      name, email = "Michael Fellinger", "mf@rubyists.com"
    when /^(?:deathsyn$|Kevin Berry)/
      name, email = "Kevin Berry", "kb@rubyists.com"
    when /^(?:(?:jayson|thedonvaughn|jvaughn)$|Jayson Vaughn)/
      name, email = "Jayson Vaughn", "jv@rubyists.com"
    end

    authors[[name, email]] += count.to_i
  end

  File.open('AUTHORS', 'w+') do |io|
    io.puts "Following persons have contributed to #{GEMSPEC.name}."
    io.puts '(Sorted by number of submitted patches, then alphabetically)'
    io.puts ''
    authors.sort_by{|(n,e),c| [-c, n.downcase] }.each do |(name, email), count|
      io.puts("%6d %s <%s>" % [count, name, email])
    end
  end
end
