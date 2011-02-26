module TinyCallCenter
  module ChannelRelay
    def relay(content)
      # Log.debug "Channel << %p" % [content]
      WebSocketChannel::Channel << content
    end

    def ext_match(ext)
      /(?:^|\/)(?:sip:)?#{ext}[@-]/
    end
    # FIXME:
    # if an agent isn't in SubscribedAgents, the message won't be relayed to
    # the WebSocketChannel
    def relay_agent(message)
      possible = possible_numbers(message)
      if message[:tiny_action] == 'call_start'
        Log.debug "<<< Call Start Channel Search >>>"
        left_chan, right_chan = message[:left][:channel], message[:right][:channel]
        Log.debug [possible, left_chan, right_chan]
        possible.select! { |num|
          left_chan =~ ext_match(num) || right_chan =~ ext_match(num)
        }
      end
      agent_lists = WebSocketReporter::SubscribedAgents.values_at(*possible).compact

      agent_lists.each do |agent_list|
        next unless agent = agent_list.last
        if agent.respond_to?(:on_fs_event)
          Log.debug "Relay found for #{agent.agent}"
          relay message.merge(cc_agent: agent.agent)
          agent.on_fs_event(message)
        else # agent is (supposed to be) a string, only relay to channel
          Log.debug "No relay found for #{agent}"
          relay message.merge(cc_agent: agent)
        end
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

      Log.debug "Possible Numbers: %p" % [possible]

      possible
    end

    def cleanup(msg)
      msg.values.each do |value|
        value.replace(CGI.unescape(value.to_str)) if value.respond_to?(:to_str)
      end

      Hash[msg.sort]
    end
  end
end
