# Copyright (c) 2008-2009 The Rubyists, LLC (effortless systems) <rubyists@rubyists.com>
# Distributed under the terms of the MIT license.
# The full text can be found in the LICENSE file included with this software

desc "migrate to latest version of db"
task :migrate, :version do |_, args|
  args.with_defaults(:version => nil)
  require File.expand_path("../../lib/fxc", __FILE__)
  require_relative "../lib/fxc/db"
  require 'sequel/extensions/migration'

  raise "No DB found" unless FXC.db

  require_relative "../model/init"

  if args.version.nil?
    Sequel::Migrator.apply(FXC.db, FXC::MIGRATION_ROOT)
  else
    Sequel::Migrator.run(FXC.db, FXC::MIGRATION_ROOT, :target => args.version.to_i)
  end

end
