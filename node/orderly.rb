module TinyCallCenter
  class Orderly
    Innate.node "/orderly", self
    helper :user
    trait :user_model => TinyCallCenter::Account

    def index
      redirect Accounts.r(:login) unless logged_in?
      @agent = user.agent
      @server = TinyCallCenter.options.listener.server
      @title = @agent
    end
  end
end
