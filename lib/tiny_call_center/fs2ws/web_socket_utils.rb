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
    def self.agent_status(extension, calls)
      return {} unless extension && calls

      sip = %r{(?:sip:|sofia/internal/)(#{extension})@}
      return {} unless founds = calls.select do |call|
        #FSR::Log.devel extension: extension, includes: [call.dest, call.cid_num, call.callee_cid_num, call.caller_cid_num]
        #FSR::Log.devel sip: sip, any: [call.caller_chan_name, call.callee_chan_name]

        [call.dest, call.cid_num, call.b_cid_num, call.callee_num, call.callee_cid_num, call.caller_cid_num, call.cid_num].include?(extension) ||
        [call.name, call.b_name, call.caller_chan_name, call.callee_chan_name].any?{|name| name.to_s =~ sip }
      end

      found_calls = founds.map { |found|
        if (found.cid_num || found.caller_cid_number) == extension
          # This is a call _from_ us
          {
            display_cid: Utils::FSR.format_display_name_and_number(found.callee_name, found.callee_num),
            id: found.uuid,
            created_epoch: found.created_epoch.to_i,
            agentId: extension,
            cond: "cid_num: (#{found.cid_num} || #{found.caller_cid_number}) == #{extension}",
            original: found,
          }
        elsif ((found.dest == extension) || ((found.callee_num || found.callee_cid_num) == extension))
          # this is a call _to_ us
          {
            display_cid: Utils::FSR.format_display_name_and_number(found.cid_num, found.cid_name),
            id: found.uuid,
            created_epoch: found.created_epoch.to_i,
            agentId: extension,
            cond: "callee_num: (#{found.callee_num} || #{found.callee_cid_num}) == #{extension}",
            original: found,
          }
        elsif found.dest && found.dest == extension && found.cid_num == extension
          # FSR::Log.debug "<<< Found Dest >>>\n" + found.inspect
          # got a Transfer here
          h = {
            display_cid: Utils::FSR.format_display_name_and_number(found.cid_name, found.cid_num),
            id: found.uuid,
            created_epoch: found.created_epoch.to_i,
            agentId: extension,
            cond: "#{found.dest} == #{extension} && #{found.cid_num} == #{extension}",
            original: found,
          }
          # FSR::Log.debug "<<< Channel Hash >>>\n" + h.inspect
          h
        elsif found.dest
          # got an FSR::Channel here
          {
            display_cid: Utils::FSR.format_display_name_and_number(found.cid_name, found.cid_num),
            id: found.uuid,
            created_epoch: found.created_epoch.to_i,
            agentId: extension,
            cond: "found.dest = #{found.dest}",
            original: found,
          }
        else
          # Assume an FSR::Call here
          # FSR::Log.debug "<<< FSR::Call >>>\n" + found.inspect
          {
            display_cid: Utils::FSR.format_display_name_and_number(found.caller_cid_name, found.caller_cid_num),
            id: found.call_uuid,
            created_epoch: found.call_created_epoch.to_i,
            agentId: extension,
            cond: "else",
            original: found,
          }
        end
      }
      # FSR::Log.debug "Sending agent status: #{found_calls}"
      found_calls.uniq{|call| call[:id] }
    end
  end
end
