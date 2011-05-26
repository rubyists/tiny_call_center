module TinyCallCenter
  class LiveLog
    Innate.node "/live_log", self
    helper :user
    layout :live_log
    trait :user_model => TinyCallCenter::Account

    def index
      redirect Accounts.r(:login) unless logged_in?
      redirect Main.r(:index) unless user.manager?

      @agent = user.agent
      @server = TinyCallCenter.options.listener.server if request.local_net?
    end
  end
end
