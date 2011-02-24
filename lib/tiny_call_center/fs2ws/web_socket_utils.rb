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

    def fsr_socket(server)
      FSR::CommandSocket.new(:server => server)
    end

    def agent_status(extension, calls)
      return {} unless extension && calls

      sip = /sip:#{extension}@/
      return {} unless founds = calls.select do |call|
        [call.dest, call.callee_cid_num, call.caller_cid_num].include?(extension) ||
        [call.caller_chan_name, call.callee_chan_name].any?{|name| name =~ sip }
      end


      found_calls = founds.map { |found|
        if found.dest && found.dest == extension && found.cid_num == extension
          FSR::Log.debug "<<< Found Dest >>>\n" + found.inspect
          # got a Transfer here
          h = {
            caller_cid_num:     found.cid_num,
            caller_cid_name:    found.cid_name,
            caller_dest_num:    found.dest,
            callee_cid_num:     found.dest,
            uuid:               found.uuid,
            call_created:       Time.at(found.created_epoch.to_i).rfc2822,
          }
          FSR::Log.debug "<<< Channel Hash >>>\n" + h.inspect
          h
        elsif found.dest
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
          FSR::Log.debug "<<< FSR::Call >>>\n" + found.inspect
          {
            caller_cid_num:     found.caller_cid_num,
            caller_cid_name:    found.caller_cid_name,
            caller_dest_num:    found.caller_dest_num,
            callee_cid_num:     found.callee_cid_num,
            uuid:               found.call_uuid,
            call_created:       Time.at(found.call_created_epoch.to_i).rfc2822,
          }
        end
      }
      FSR::Log.debug "Sending agent status: #{found_calls}"
      found_calls.uniq{|call| call[:uuid] }
    end

    def reply(obj)
      socket.send(obj.to_json)
    end
  end
end
