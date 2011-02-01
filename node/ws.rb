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

      if TinyCallCenter.options.off_hook
        command_server = TinyCallCenter.options.command_server
        sock = FSR::CommandSocket.new(:server => command_server)
        FSR.load_all_commands
        if user.registration_server == command_server
          sock.originate(target: "{tcc_agent=#{@agent}}user/#{user.extension}",
                        endpoint: "&transfer(19999)").run
        else
          sock.originate(target: "{tcc_agent=#{@agent}}sofia/internal/#{user.extension}@#{user.registration_server}",
                        endpoint: "&transfer(19999)").run
        end
      end
    end
  end
end
