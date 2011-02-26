# Copyright (c) 2008-2009 The Rubyists, LLC (effortless systems) <rubyists@rubyists.com>
# Distributed under the terms of the MIT license.
# The full text can be found in the LICENSE file included with this software
#
module TinyCallCenter
  class Accounts
    Innate.node "/accounts", self
    helper :user
    trait :user_model => TinyCallCenter::Account
    layout :main

    def login
      return unless request.post?
      user_login(request.subset(:name, :pass))
      redirect "/"
    end

    def logout
      user_logout
      redirect_referer
    end

  end
end
