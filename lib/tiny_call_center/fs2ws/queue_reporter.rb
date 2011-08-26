module TinyCallCenter
  class QueueReporter < FSR::Listener::Inbound
    include ChannelRelay

    def before_session
      add_event(:CUSTOM, "callcenter::info", &method(:callcenter_info))
      @responses = []
      start_callcenter_queue
    end

    def last_response
      @responses.last
    end

    def handle_request(headers, content)
      FSR::Log.devel "<<< Callcenter Response : #{[headers, content].inspect} >>>"
      @responses = @responses[-20, 20] if @responses.size > 40
      @responses << [headers, content]
    end

    def callcenter_info(event)
      content = cleanup(event.content)

      FSR::Log.debug "<<< Callcenter Info : #{content[:cc_action]} >>>"
      FSR::Log.debug content

      case content[:cc_action]
      when 'cc_queue_count'
        relay content
      when 'agent-status-change'
        relay_agent content.merge(tiny_action: 'status_change')
      when 'agent-state-change'
        relay_agent content.merge(tiny_action: 'state_change')
      when 'bridge-agent-start'
        bridge_agent_start(content)
      when 'bridge-agent-end'
        bridge_agent_end(content)
      else
        relay content
      end
    end

    def bridge_agent_start(msg)
      File.open("/tmp/bridge-agent-start.log", "a+") { |f| f.print msg }
      return unless msg[:answer_state] == 'answered' &&
                    msg[:caller_destination_number] == '19999'

      out = {
        tiny_action: 'call_start',
        call_created: msg[:variable_rfc2822_date],
        cc_agent: msg[:cc_agent],
        producer: 'bridge_agent_start',
        original: msg,

        left: {
          cid_number:  msg[:caller_caller_id_number],
          cid_name:    msg[:caller_caller_id_name],
          channel:     msg[:caller_channel_name],
          destination: msg[:variable_dialed_user] || msg[:variable_cc_agent][/^(\d+)-/, 1],
          uuid:        msg[:cc_agent_uuid],
        },
        right: {
          cid_number:  msg[:cc_caller_cid_number] || msg[:cc_member_cid_number],
          cid_name:    msg[:cc_caller_cid_name] || msg[:cc_member_cid_name],
          channel:     msg[:channel_name],
          destination: msg[:variable_dialed_user] || msg[:variable_cc_agent][/^(\d+)-/, 1],
          uuid:        msg[:cc_caller_uuid] || msg[:cc_member_session_uuid],
        }
      }

      bridge_agent_start_check(out, :left)
      bridge_agent_start_check(out, :right)

      FSR::Log.debug "!!! Bridge Agent Start Initiates Call Start !!!"
      FSR::Log.debug out

      relay_agent out
    end

    def bridge_agent_start_check(hash, leg_name)
      leg = hash[leg_name]
      FSR::Log.warn("#{leg_name} has missing cid_number") unless leg[:cid_number]
      FSR::Log.warn("#{leg_name} has missing cid_name") unless leg[:cid_name]
      FSR::Log.warn("#{leg_name} has missing channel") unless leg[:channel]
      FSR::Log.warn("#{leg_name} has missing destination") unless leg[:destination]
      FSR::Log.warn("#{leg_name} has missing uuid") unless leg[:uuid]
    end

    def bridge_agent_end(msg)
      File.open('/tmp/bridge-agent-end.log', 'w+'){|io| io.write(msg.pretty_inspect) }
      out = msg.merge(
        tiny_action: 'call_end',
        call_created: msg[:variable_rfc2822_date],
        cc_agent: msg[:cc_agent],
        producer: 'bridge_agent_end',
        original: msg
      )

      relay_agent(out)
    end

    # @cc_queue forces all calls on @cc_cmd into sequencial order to avoid
    # possible state collisions while maintaining a single connection.
    def start_callcenter_queue
      @cc_cmd = FSR::Cmd::CallCenter.new(nil, :agent)
      @cc_queue = EM::Queue.new
    end

    # please note that this doesn't happen immediately, so don't try to rely on
    # any changes after calling it.
    def callcenter!(&given_block)
      @cc_queue.push(given_block)

      # the pop doesn't happen immediately, will be scheduled later
      @cc_queue.pop do |block|
        block.call(@cc_cmd)
        FSR::Log.info @cc_cmd.raw
        api @cc_cmd.raw
      end
    end
  end
end
