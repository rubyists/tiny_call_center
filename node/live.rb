module TinyCallCenter
  class Live
    Innate.node "/live", self
    helper :user, :fsr
    layout :live
    trait :user_model => TinyCallCenter::Account

    def index
      redirect Accounts.r(:login) unless logged_in?
      redirect Main.r(:index) unless user.manager?

      @agent = user.agent
      @server = TinyCallCenter.options.listener.server if request.local_net?
      @couch_uri = TinyCallCenter.options.tiny_cdr.couch_uri
      @title = @agent
    end
  end
end
