module TinyCallCenter
  class QueueReporter < FSR::Listener::Inbound
    include ChannelRelay

    def before_session
      add_event(:CUSTOM, "callcenter::info", &method(:callcenter_info))
    end

    def callcenter_info(event)
      content = Hash[event.content.map{|k,v| [k, CGI.unescape(v)] }]

      FSR::Log.debug "received callcenter_info event #{content}"

      case content[:cc_action]
      when 'cc_queue_count'
        # ignore
      when 'agent-status-change'
        relay_agent cleanup(content).merge(tiny_action: 'status_change')
      when 'agent-state-change'
        relay_agent cleanup(content).merge(tiny_action: 'state_change')
      else
        relay cleanup(content)
      end
    end

    def cleanup(msg)
      msg.reject! do |k,v|
        k !~ /^(cc|event)_/ ||
        k =~ /^event_(subclass|name|date_local|calling_file|calling_function|calling_line_number)$/
      end
    end

    def callcenter
      @callcenter ||= FSR::Cmd::CallCenter.new(nil, :agent)
    end

    def callcenter!
      yield callcenter
      FSR::Log.info callcenter.raw
      api callcenter.raw
    end
  end
end
