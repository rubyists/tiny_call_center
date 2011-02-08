class Main
  include Innate::Node
  helper :user
  trait :user_model => TinyCallCenter::Account
  map '/'

  def index
    redirect TinyCallCenter::Accounts.r(:login) unless logged_in?
  end
end
