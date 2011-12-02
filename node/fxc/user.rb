module TCC
  module FXC
    class User
      Innate.node '/fxc/user', self
      layout :fxc

      def index
        @users = ::FXC::User.order(:extension)
      end

      def view(uid)
        @user = ::FXC::User[id: uid.to_i]
      end

      def create
        @user = ::FXC::User.new

        return unless request.post?

        @user.extension = request[:extension]
        @user.fullname = request[:fullname]
        @user.save

        redirect r(:index)
      end

      def update(uid)
        redirect_referer unless request.post?

        @user = ::FXC::User[id: uid.to_i]
        @user.update(
          fullname: request[:fullname],
          extension: request[:extension],
          active: request[:active] == 'on',
        )
        redirect r(:index)
      end

      def delete(uid)
        @user = ::FXC::User[id: uid.to_i]

        return unless request.post?

        @user.destroy

        redirect r(:index)
      end
    end
  end
end
