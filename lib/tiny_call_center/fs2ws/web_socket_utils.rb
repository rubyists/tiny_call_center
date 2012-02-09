module TinyCallCenter
  module WebSocketUtils
    STATUS_MAPPING = {
      'available' => 'Available',
      'available_on_demand' => 'Available (On Demand)',
      'on_break' => 'On Break',
      'logged_out' => 'Logged Out',
    }

    STATE_MAPPING = {
      'Idle' => 'Wrap Up',
      'idle' => 'Wrap Up',
      'Waiting' => 'Ready',
      'waiting' => 'Ready',
    }

    # Check the agents extension against all the calls passed in.
    # When new Channel or Call fields are added, the calls.select
    # block needs to know about them
    def agent_status(extension, calls)
      return {} unless extension && calls

      sip = /sip:#{extension}@/
      return {} unless founds = calls.select do |call|
        #FSR::Log.devel extension: extension, includes: [call.dest, call.cid_num, call.callee_cid_num, call.caller_cid_num]
        #FSR::Log.devel sip: sip, any: [call.caller_chan_name, call.callee_chan_name]

        [call.dest, call.callee_cid_num, call.caller_cid_num, call.cid_num].include?(extension) ||
        [call.caller_chan_name, call.callee_chan_name].any?{|name| name =~ sip }
      end

      found_calls = founds.map { |found|
        if found.dest && found.dest == extension && found.cid_num == extension
          FSR::Log.debug "<<< Found Dest >>>\n" + found.inspect
          # got a Transfer here
          h = {
            cid_name: found.cid_name,
            cid_number: found.cid_num,
            uuid: found.uuid,
            created: Time.at(found.created_epoch.to_i).rfc2822,
            agentId: extension,
          }
          FSR::Log.debug "<<< Channel Hash >>>\n" + h.inspect
          h
        elsif found.dest
          # got an FSR::Channel here
          {
            cid_name: found.dest,
            cid_number: found.dest,
            uuid: found.uuid,
            created: Time.at(found.created_epoch.to_i).rfc2822,
            agentId: extension,
          }
        else
          # Assume an FSR::Call here
          FSR::Log.debug "<<< FSR::Call >>>\n" + found.inspect
          {
            caller_cid_num:     found.caller_cid_num,
            caller_cid_name:    found.caller_cid_name,
            caller_dest_num:    found.caller_dest_num,
            callee_cid_num:     found.callee_cid_num,
            uuid:               found.call_uuid,
            call_created:       Time.at(found.call_created_epoch.to_i).rfc2822,
            agentId: extension,
          }
        end
      }
      FSR::Log.debug "Sending agent status: #{found_calls}"
      found_calls.uniq{|call| call[:uuid] }
    end
  end
end
