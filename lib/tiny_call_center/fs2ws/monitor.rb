module TinyCallCenter
  class Monitor < FSR::Listener::Inbound
    include ChannelRelay

    def initialize(*args, &callback)
      @channel_answers = {}
      @channel_originates = {}
      super
    end

    def before_session
      [ :CHANNEL_ORIGINATE, # Call being placed/ringing
        :CHANNEL_ANSWER,    # Call starts
        :CHANNEL_HANGUP,    # Call ends
      ].each{|flag| add_event(flag, &method(flag.to_s.downcase)) }
    end

    def channel_originate(event)
      cont, uuid = event.content, event.content[:unique_id]
      FSR::Log.debug "Call Origniated: %s => %s (%s) (%s)" % [cont[:caller_caller_id_number], cont[:caller_destination_number], uuid, cont[:other_leg_unique_id]]
      FSR::Log.info cont.inspect

      clean_event = cleanup_msg(cont)
      @channel_originates[uuid] = clean_event
      @channel_originates[cont[:other_leg_unique_id]] = clean_event
      try_call_dispatch(uuid, cont[:other_leg_unique_id])
    end

    def channel_answer(event)
      content = event.content

      FSR::Log.debug "Call answered: %s <%s> => %s (%s)" % [
        content[:caller_caller_id_number],
        content[:caller_caller_id_name],
        content[:caller_destination_number],
        content[:unique_id],
      ]

      @channel_answers[content[:unique_id]] = cleanup_msg(content)
      try_call_dispatch(content[:unique_id])
    end

    def channel_hangup(event)
      content = event.content

      FSR::Log.debug "Call hungup: %s <%s> => %s (%s)" % [
        content[:caller_caller_id_number],
        content[:caller_caller_id_name],
        content[:caller_destination_number],
        content[:unique_id],
      ]

      relay_agent cleanup_msg(content).merge(tiny_action: 'channel_hangup')
    end

    def cleanup_msg(content)
      msg = content.reject do |key, value|
        key =~ /^variable_/
      end

      msg.values.each do |value|
        value.replace(CGI.unescape(value.to_str)) if value.respond_to?(:to_str)
      end

      msg
    end

    def dispatch_call(left, right, originate)
      msg = {
        tiny_action: 'call_start',
        call_created: originate[:event_date_gmt],
        queue_name: originate[:cc_queue],

        left: {
          cid_number:   left[:caller_caller_id_number],
          cid_name:   left[:caller_caller_id_name],
          destination:   left[:caller_destination_number],
          channel:   left[:caller_channel_name],
          uuid:   left[:unique_id],
        },

        right: {
          cid_number: right[:caller_caller_id_number],
          cid_name: right[:caller_caller_id_name],
          destination: right[:caller_destination_number],
          channel: right[:caller_channel_name],
          uuid: right[:unique_id],
        }
      }

      FSR::Log.debug "Dispatching call #{msg}"
      relay_agent msg
    end

    def try_call_dispatch(left, right = nil)
      # If we're an originate, check for both answers
      if right
        return unless left_answer = @channel_answers[left]
        return unless right_answer = @channel_answers[right]
        originate = @channel_originates[left]
        dispatch_call(left_answer, right_answer, originate) if left_answer and right_answer
      elsif left_answer = @channel_answers[left]
        return unless originate = @channel_originates[left]
        if left == originate[:other_leg_unique_id]
          return unless right_answer = @channel_answers[originate[:unique_id]]
        else
          return unless right_answer = @channel_answers[originate[:other_leg_unique_id]]
        end
        dispatch_call(left_answer, right_answer, originate) if left_answer and right_answer
      end
    end
  end
end
