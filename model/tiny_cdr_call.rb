module TinyCallCenter
  module TinyCdr
    class Call < Sequel::Model
      set_dataset TinyCdr.db[:calls]
      def destination
        if destination_number =~ /^\d\d{8,}$/
          destination_number[-10,10]
        else
          destination_number
        end
      end

      def queue_call?
        channel =~ /#{Regexp.escape(TinyCallCenter.options.command_server)}(:\d\d{1,3})?$/
      end
    end
  end
end
