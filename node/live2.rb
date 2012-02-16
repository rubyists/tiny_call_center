module TinyCallCenter
  class Live2
    Innate.node "/live2", self
    helper :user, :fsr, :localize
    layout :live2
    trait :user_model => TinyCallCenter::Account

    def index
      redirect Accounts.r(:login) unless logged_in?
      redirect Main.r(:index) unless user.manager?

      @agent = user.agent
      @server = TinyCallCenter.options.live2.server if request.local_net?
      @couch_uri = TinyCallCenter.options.tiny_cdr.couch_uri
      @title = @agent
    end
  end
end
