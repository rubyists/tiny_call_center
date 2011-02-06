module TinyCallCenter
  module ChannelRelay
    def relay(content)
      # FSR::Log.debug "Channel << %p" % [content]
      WebSocketChannel::Channel << content
    end

    # FIXME:
    # if an agent isn't in SubscribedAgents, the message won't be relayed to
    # the WebSocketChannel
    def relay_agent(message)
      possible = possible_numbers(message)
      FSR::Log.debug "Relay #{message} to #{possible}"
      agent_lists = WebSocketReporter::SubscribedAgents.values_at(*possible).compact
      FSR::Log.debug "Relay found #{agent_lists}"

      agent_lists.each do |agent_list|
        next unless agent = agent_list.last
        relay message.merge(cc_agent: agent.agent)
        agent.on_fs_event(message)
      end
    end

    def possible_numbers(message)
      possible = [
        TCC::Account.extension(message[:cc_agent].to_s),
        TCC::Account.extension(message[:variable_tcc_agent].to_s),
        *(message[:left] || {}).values_at(:destination, :cid_number),
        *(message[:right] || {}).values_at(:destination, :cid_number),
        message[:caller_callee_id_number],
        message[:caller_destination_number],
        message[:callee_destination_number],
        message[:other_leg_callee_id_number],
        message[:other_leg_caller_id_number],
        message[:caller_rdnis],
        message[:other_leg_rdnis],
      ].grep(/^\d{4}$/).uniq

      FSR::Log.debug "Possible Numbers: #{possible}"

      possible
    end
  end
end
