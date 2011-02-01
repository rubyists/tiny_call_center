module TinyCallCenter
  module ChannelRelay
    def relay(content)
      # FSR::Log.debug "Channel << %p" % [content]
      WebSocketChannel::Channel << content
    end

    def relay_agent(message)
      relay message # for Channel

      if agent = message[:cc_agent]
        keys = [TCC::Account.extension(message[:cc_agent])]
      else
        keys = possible_numbers(message)
      end

      keys.find{|key|
        if subscribed = WebSocketReporter::SubscribedAgents[key]
          break unless agent = subscribed.last
          agent.on_fs_event(message)
          break
        end
      }
    end

    def possible_numbers(message)
      FSR::Log.debug possible_numbers: message
      [ *(message[:left] || {}).values_at(:destination, :cid_number),
        *(message[:right] || {}).values_at(:destination, :cid_number),
        message[:caller_callee_id_number],
        message[:caller_destination_number],
        message[:callee_destination_number],
        message[:other_leg_callee_id_number],
        message[:other_leg_caller_id_number],
        message[:caller_rdnis],
        message[:other_leg_rdnis],
      ].uniq.compact
    end
  end
end
