module TinyCallCenter
  class Main
    Innate.node '/', self
    helper :user
    layout :main
    trait :user_model => TinyCallCenter::Account

    def index
      redirect TCC::Accounts.r(:login) unless logged_in?
      @popup = true
    end
  end
end
