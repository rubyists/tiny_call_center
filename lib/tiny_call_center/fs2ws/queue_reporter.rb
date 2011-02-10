module TinyCallCenter
  class QueueReporter < FSR::Listener::Inbound
    include ChannelRelay

    def before_session
      add_event(:CUSTOM, "callcenter::info", &method(:callcenter_info))
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
      else
        relay content
      end
    end

    def bridge_agent_start(msg)
      return unless msg[:answer_state] == 'answered' && msg[:caller_destination_number] == '19999'

      out = {
        tiny_action: 'call_start',
        call_created: msg[:variable_rfc2822_date],
        cc_agent: msg[:cc_agent],

        left: {
          cid_number: msg[:caller_caller_id_number],
          cid_name:   msg[:caller_caller_id_name],
          channel:    msg[:caller_channel_name],
          uuid:       msg[:variable_call_uuid],
        },
        right: {
          cid_number: msg[:cc_caller_cid_number],
          cid_name:   msg[:cc_caller_cid_name],
          channel:    msg[:channel_name],
          uuid:       msg[:channel_call_uuid],
        }
      }

      FSR::Log.debug "!!! Bridge Agent Start Initiates Call Start !!!"
      FSR::Log.debug out

      relay_agent out
    end

    def member_queue_start(msg)
      if msg[:answer_state] == 'answered' && (msg[:caller_caller_id_number] == '8675309' || msg[:caller_destination_number] == '19999')
        relay_msg = {
          tiny_action: 'call_start',
          call_created: msg[:event_date_gmt],
          cc_agent: msg[:cc_agent] || msg[:variable_cc_agent],

          left: {
            cid_number:  msg[:caller_caller_id_number],
            cid_name:    msg[:caller_caller_id_name],
            destination: msg[:caller_destination_number],
            channel:     msg[:caller_channel_name],
            uuid:        msg[:unique_id],
          },

          right: {
            cid_number:  msg[:caller_caller_id_number],
            cid_name:    msg[:caller_caller_id_name],
            destination: msg[:caller_destination_number],
            channel:     msg[:channel_name],
            uuid:        msg[:unique_id],
          }
        }

        relay_agent relay_msg
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
