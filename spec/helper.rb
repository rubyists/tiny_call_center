# Copyright (c) 2008-2009 The Rubyists, LLC (effortless systems) <rubyists@rubyists.com>
# Distributed under the terms of the MIT license.
# The full text can be found in the LICENSE file included with this software
#

require "fsr"
require File.expand_path("../spec/fsr_listener_helper", FSR::ROOT)
require File.expand_path("fsr/listener/outbound", FSR::ROOT)
require File.expand_path("fsr/listener/mock", FSR::ROOT)
require "em-spec/bacon"
require 'nokogiri'
require 'uri'

db = ENV['TCC_DB'] ||= "postgres://callcenter@localhost/tcc_spec"
uri = URI(db)
case uri.scheme
when 'postgres'
  db_name = uri.path.split('/').last
  system('dropdb', '-U', 'postgres', db_name)
  system('createdb', '-U', 'postgres', db_name)
else
  raise 'we only support postgres for now'
end

system('rake', 'migrate')

require_relative '../options'
TinyCallCenter.options.db = db
TinyCallCenter.options.mode = 'spec'

require_relative '../lib/tiny_call_center'
require_relative "../lib/tiny_call_center/db"
require_relative '../app'

Innate::Log.loggers = [Logger.new($stdout)]
Innate.options.roots = [File.expand_path('../../', __FILE__)]

require 'innate/spec/bacon'

Innate.middleware! :spec do |m|
  m.use Rack::Lint
  m.use Rack::CommonLogger, Innate::Log
  m.innate
end

Bacon.summary_on_exit

require_relative '../helper/user'

module Innate
  module Helper
    module User
      def logged_in?
        logged_in_already = user._logged_in?
        return logged_in_already if logged_in_already

        user._login('name' => 'MrAdmin', 'pass' => 'not_a_pass')
        user._logged_in?
      end
    end
  end
end

shared :make_account do
  def make_manager(account)
    TCC::Manager.create(
      username: account.username,
      admin: true
    )
  end

  def make_account(ext, pass, first, last)
    TCC::Account.create(
      username: "#{first}#{last}",
      password: pass,
      first_name: first,
      last_name: last,
      extension: ext,
      registration_server: 'foo.bar.bit'
    )
  end

  before{
    TCC::Manager.delete
    TCC::Account.delete
    make_manager(make_account('5432', 'not_a_pass', 'Mr', 'Admin'))
  }
end
