# Copyright (c) 2010-2011 The Rubyists, LLC (effortless systems) <rubyists@rubyists.com>
# Distributed under the terms of the MIT license.
# The full text can be found in the LICENSE file included with this software
#
require "fsr"
require "fsr/command_socket"

module TinyCallCenter
  class Ribbon
    Innate.node "/ribbon", self
    helper :user
    helper :localize
    trait :user_model => TinyCallCenter::Account

    def index
      redirect Accounts.r(:login) unless logged_in?
      @agent = user.agent
      @extension = user.extension
      @server = TinyCallCenter.options.ribbon.server if request.local_net?
      @title = @agent
    end

    alias v2 index
    alias v3 index
  end
end
