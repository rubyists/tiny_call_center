# Copyright (c) 2008-2009 The Rubyists, LLC (effortless systems) <rubyists@rubyists.com>
# Distributed under the terms of the MIT license.
# The full text can be found in the LICENSE file included with this software
#
require "fsr"
require "fsr/command_socket"

module TinyCallCenter
  class Ws
    Innate.node "/ws", self
    helper :user
    trait :user_model => TinyCallCenter::Account
    layout :ws

    def who
      request.inspect
    end
    def index
      redirect Accounts.r(:login) unless logged_in?
      @agent = user.agent
      @extension = user.extension
      octet = "(?:[01][0-5][0-5]|2[0-5][0-5])"
      ip_regex = /^(?:#{octet}\.){3}#{octet}/
      @server = if request.env["SERVER_NAME"] =~ ip_regex
                  TinyCallCenter.options.ribbon.server.sub /ws:\/\/#{ip_regex}:/ws:\/\/#{request.env["SERVER_NAME"]}:/
                else
                  TinyCallCenter.options.ribbon.server
                end
      @title = @agent
    end
  end
end
