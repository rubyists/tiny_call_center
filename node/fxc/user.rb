module TCC
  module FXC
    class User
      Innate.node '/fxc/user', self
      layout :fxc
      helper :localize

      def index
        @users = ::FXC::User.order(:extension)
      end

      def view(uid)
        @user = ::FXC::User[id: uid.to_i]
        @tod_rules = @user.time_of_day_routing_rules
        @errors = {}

        return unless request.post?

        redirect r(:index) if request['cancel']

        @user.update(
          fullname: request[:fullname],
          extension: request[:extension],
          active: request[:active] == 'on',
        )

        redirect r(:index)

      rescue Sequel::ValidationFailed => err
        @errors = err.errors
      end

      def create
        @user = ::FXC::User.new

        return unless request.post?

        @user.extension = request[:extension]
        @user.fullname = request[:fullname]
        @user.save

        redirect r(:index)
      end

      def delete(uid)
        @user = ::FXC::User[id: uid.to_i]

        return unless request.post?

        @user.destroy

        redirect r(:index)
      end

      WDAYS = %w[mon tue wed thu fri sat sun]

      def add_route
        respond 'Only POST accepted', 405 unless request.post?

        user = ::FXC::User[id: request[:uid]]

        # mon=0, tue=1, ...
        # freeswitch wants mon=2, tue=3
        from_wday, to_wday =
          request[:from_wday, :to_wday].map{|wday| WDAYS[wday.to_i] }

        # minutes since midnight
        from_minute, to_minute = request[:from_minute, :to_minute].map(&:to_i)

        target = request[:target]

        user.add_time_of_day_rule(
          from_minute, to_minute,
          from_wday, to_wday,
          [{action: :dial, numbers: [target]}]
        )
      end

      private

      def localize_dictionary
        TCC::DICTIONARY
      end
    end
  end
end
