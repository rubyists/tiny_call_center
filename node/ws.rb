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

    def index
      redirect Accounts.r(:login) unless logged_in?
      @agent = user.agent
      @extension = user.extension
      @server = TinyCallCenter.options.ribbon.server
      @title = @agent
    end
  end
end
