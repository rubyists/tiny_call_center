# Copyright (c) 2008-2009 The Rubyists, LLC (effortless systems) <rubyists@rubyists.com>
# Distributed under the terms of the MIT license.
# The full text can be found in the LICENSE file included with this software
#

require "fsr"
require FSR::ROOT/"../spec/fsr_listener_helper"
require FSR::ROOT/"fsr/listener/outbound"
require FSR::ROOT/"fsr/listener/mock"
require "em-spec/bacon"
require 'nokogiri'

require_relative '../lib/tiny_call_center'
require_relative "../lib/tiny_call_center/db"
require_relative '../app'

TinyCallCenter.options.db = "sqlite://:memory:"

Innate::Log.loggers = [Logger.new($stdout)]
Innate.options.roots = [File.expand_path('../../', __FILE__)]

require 'innate/spec/bacon'
Innate.middleware! :spec do |m|
  m.use Rack::Lint
  m.use Rack::CommonLogger, Innate::Log
  m.innate
end

Bacon.summary_on_exit

shared :make_account do
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

  before{ TCC::Account.delete }
end
