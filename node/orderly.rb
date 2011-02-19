module TinyCallCenter
  class Orderly
    Innate.node "/orderly", self
    helper :user, :fsr
    trait :user_model => TinyCallCenter::Account

    def index
      redirect Accounts.r(:login) unless logged_in?
      redirect Main.r(:index) unless user.manager?

      @agent = user.agent
      @server = TinyCallCenter.options.listener.server if request.local_net?
      @title = @agent
    end
  end
end
