module TinyCallCenter
  module QueueRouter
    class Listener < FSR::Listener::Outbound
      def session_initiated
        destination = @session.headers[:caller_destination_number]
        Log.info "<< Session initiated to #{destination} >>"
        if queue = TCC::CallCenter::Tier.extension_primary_queue(destination)
          name = queue[:queue]
        else
          name = "7171"
        end
        pre_answer do
          Log.info "<< Transfer to #{name} XML default >>"
          transfer(name, "XML", "default") { close_connection }
        end
      end
    end
  end
end
