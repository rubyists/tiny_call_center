module TinyCallCenter
  class Managers
    Innate.node "/managers", self
    helper :user
    helper :localize
    trait :user_model => TinyCallCenter::Account
    layout :managers

    before_all do
      @title = "Managers"
    end

    def index
      @managers = Manager.sort_by{|m| m.username }
    end

    def new
      @submit ||= "Add Manager"
      @legend ||= "New Manager details"
      @usernames = Account.all_usernames
      @manager = Manager.new

      if request.post?
        @manager.username = request[:username]
        @manager.include = request[:include]
        @manager.exclude = request[:exclude]
        @manager.save
        redirect r(:index)
      end

      # when adding a new manager, we want to give nice defaults for include/exclude
      # so i'll search the db for the most common for each

      includes, excludes = Hash.new(0), Hash.new(0)
      Manager.each do |manager|
        includes[manager.include] += 1
        excludes[manager.exclude] += 1
      end

      @manager.include = includes.max_by{|k,v| v }.first if includes.any?
      @manager.exclude = excludes.max_by{|k,v| v }.first if excludes.any?
    end

    def edit(id, name = nil)
      @manager = Manager[id.to_i]

      if request.post?
        @manager.username = request[:username]
        @manager.include = request[:include]
        @manager.exclude = request[:exclude]
        @manager.save
        redirect_referrer
      end

      render_view :new, legend: "Manager details", submit: "Add Manager", usernames: Account.all_usernames
    end

    def delete(id, name = nil)
      redirect_referrer unless request.post?
      @manager = Manager[id.to_i]
      @manager.destroy
      redirect_referrer
    end
  end
end
