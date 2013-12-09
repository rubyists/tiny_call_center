module TinyCallCenter
  module TinyCdr
    class Call < Sequel::Model
      set_dataset TinyCdr.db[:calls]

      def self.last(extension)
        history(extension).limit(1).first
      end

      def self.history(extension, from = Date.today, to = nil)
        Log.debug("Extension is %s" % extension)
        ds = filter("(username = '#{extension}' or destination_number = '#{extension}') and (start_stamp > '#{from}')")
        ds = ds.filter{(start_stamp < to)} if to
        ds.order_by(Sequel.desc(:start_stamp))
      end

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
