# Copyright (c) 2008-2011 The Rubyists, LLC (effortless systems) <rubyists@rubyists.com>
# Distributed under the terms of the MIT license.
# The full text can be found in the LICENSE file included with this software
#
module TinyCallCenter
  class Queues
    Innate.node "/queues", self
    helper :user, :fsr, :localize
    layout :default
    trait :user_model => TinyCallCenter::Account

    trait queues: nil

    before_all do
      redirect TCC::Accounts.r(:login) unless logged_in?
    end

    def index(queue_name = nil)
      @queues = ancestral_trait[:queues] ||
        fsr.call_center(:queue).list(queue_name).run
    end
  end
end
