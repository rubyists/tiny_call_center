# Copyright (c) 2008-2009 The Rubyists, LLC (effortless systems) <rubyists@rubyists.com>
# Distributed under the terms of the MIT license.
# The full text can be found in the LICENSE file included with this software
#
module TinyCallCenter
  class Accounts
    Innate.node "/accounts", self
    helper :user
    helper :localize
    trait :user_model => TinyCallCenter::Account
    layout :main

    def login
      Log.info "Attempt login with backend: %p" % [TCC.options.backend]
      return unless request.post?
      user_login(request.subset(:name, :pass))
      Log.info "Login successful: #{logged_in?}"
      redirect Main.r('/')
    end

    def logout
      user_logout
      redirect_referer
    end

  end
end
