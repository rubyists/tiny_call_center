require "fsr"
require "fsr/command_socket"

module TinyCallCenter
  class Ribbon2
    Innate.node "/ribbon2", self
    helper :user, :localize
    trait :user_model => TinyCallCenter::Account
    layout :ribbon2

    def index
      redirect Accounts.r(:login) unless logged_in?
      @agent = user.agent
      @extension = user.extension
      @server = TinyCallCenter.options.ribbon2.server if request.local_net?
      @server = 'ws://falcon.rubyists.com:43443'
      @title = @agent
    end
  end
end
