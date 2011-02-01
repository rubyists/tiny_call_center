module TinyCallCenter
  module WebSocketUtils
    STATUS_MAPPING = {
      'available' => 'Available',
      'available_on_demand' => 'Available (On Demand)',
      'on_break' => 'On Break',
      'logged_out' => 'Logged Out',
    }

    STATE_MAPPING = {
      'ready' => 'Waiting',
      'wrap_up' => 'Idle'
    }


    def fsr_socket(server)
      FSR::CommandSocket.new(:server => server)
    end

    def agent_status(extension, calls)
      return {} unless extension && calls

      sip = /sip:#{extension}@/
      return {} unless found = calls.find do |call|
        [call.dest, call.callee_cid_num, call.caller_cid_num].include?(extension) ||
        [call.caller_chan_name, call.callee_chan_name].any?{|name| name =~ sip }
      end

      stat = if found.dest
        # got an FSR::Channel here
        {
          caller_cid_num:     found.cid_num,
          caller_cid_name:    found.cid_name,
          caller_dest_num:    found.dest,
          callee_cid_num:     found.dest,
          uuid:               found.uuid,
          call_created:       Time.at(found.created_epoch.to_i).rfc2822,
        }
      else
        # Assume an FSR::Call here
        {
          caller_cid_num:     found.caller_cid_num,
          caller_cid_name:    found.caller_cid_name,
          caller_dest_num:    found.caller_dest_num,
          callee_cid_num:     found.callee_cid_num,
          uuid:               found.call_uuid,
          call_created:       Time.at(found.call_created_epoch.to_i).rfc2822,
        }
      end
      FSR::Log.debug "Sending agent status: #{stat}"
      stat
    end

    def got_status_of(msg)
      mapped = STATUS_MAPPING[msg['status']]
      agent = msg['agent']
      reporter.callcenter!{|cc| cc.set(agent, :status, mapped) }
    end

    def reply(obj)
      socket.send(obj.to_json)
    end
  end
end
