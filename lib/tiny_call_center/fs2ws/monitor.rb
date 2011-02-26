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
        #:CHANNEL_CREATE,    # Channel created
      ].each{|flag| add_event(flag, &method(flag.to_s.downcase)) }
    end

    def channel_create(event)
      msg = cleanup(event.content)
      relay msg
    end

    def channel_originate(event)
      content, uuid = event.content, event.content[:unique_id]
      Log.debug "Call Origniated: %s => %s (%s) (%s)" % [
        content[:caller_caller_id_number],
        content[:caller_destination_number],
        uuid,
        content[:other_leg_unique_id]
      ]

      msg = cleanup(content)
      Log.debug "<<< Channel Originate >>>"
      Log.debug msg

      return if try_pure_originate(msg)

      @channel_originates[uuid] = msg
      @channel_originates[content[:other_leg_unique_id]] = msg
      try_call_dispatch(uuid, content[:other_leg_unique_id])
    end

    def try_pure_originate(msg)
      return unless msg[:answer_state] == 'answered' &&
        [msg[:caller_caller_id_number], msg[:caller_callee_id_number]].include?('8675309')

      out = {
        tiny_action: 'call_start',
        call_created: msg[:event_date_gmt],
        cc_agent: msg[:variable_tcc_agent],
        producer: 'try_pure_originate',
        original: msg,

        left: {
          cid_number:   msg[:caller_caller_id_number],
          cid_name:     msg[:caller_caller_id_name],
          destination:  msg[:caller_destination_number],
          channel:      msg[:caller_channel_name],
          uuid:         msg[:caller_unique_id],
        },
        right: {
          cid_number:   msg[:caller_caller_id_number],
          cid_name:     msg[:caller_caller_id_name],
          destination:  msg[:caller_destination_number],
          channel:      msg[:channel_name],
          uuid:         msg[:caller_unique_id],
        }
      }

      relay_agent(out)
      true
    end

    def channel_answer(event)
      content = event.content

      Log.debug "Call answered: %s <%s> => %s (%s)" % [
        content[:caller_caller_id_number],
        content[:caller_caller_id_name],
        content[:caller_destination_number],
        content[:unique_id],
      ]

      msg = cleanup(content)
      Log.debug "<<< Channel Answer >>>"
      Log.debug msg

      return if try_pure_channel_answer(msg)

      @channel_answers[content[:unique_id]] = msg
      try_call_dispatch(content[:unique_id])
    end

    def try_pure_channel_answer(msg)
      return unless msg[:call_direction] == 'inbound' &&
        msg[:answer_state] == 'answered' &&
        msg[:caller_destination_number] == '19999' &&
        msg[:channel_call_state] == 'ACTIVE'

      out = {
        tiny_action: 'call_start',
        call_created: msg[:event_date_gmt],
        cc_agent: msg[:variable_tcc_agent],
        producer: 'try_pure_channel_answer',
        original: msg,

        left: {
          cid_number:   msg[:caller_caller_id_number],
          cid_name:     msg[:caller_caller_id_name],
          destination:  msg[:caller_destination_number],
          channel:      msg[:caller_channel_name],
          uuid:         msg[:variable_uuid],
        },
        right: {
          cid_number:   msg[:caller_caller_id_number],
          cid_name:     msg[:caller_caller_id_name],
          destination:  msg[:caller_destination_number],
          channel:      msg[:channel_name],
          uuid:         msg[:channel_uuid],
        }
      }

      relay_agent(out)
      true
    end


    def channel_hangup(event)
      msg = event.content

      Log.debug "Call hungup: %s <%s> => %s (%s)" % msg.values_at(
        :caller_caller_id_number, :caller_caller_id_name,
        :caller_destination_number, :unique_id,
      )

      Log.debug "<<< Channel Hangup >>>"
      Log.debug msg

      relay_agent prepare_channel_hangup(msg)
    end

    def prepare_channel_hangup(msg)
      cleanup(msg).merge(tiny_action: 'channel_hangup')
    end

    def dispatch_call(left, right, originate)
      msg = {
        tiny_action: 'call_start',
        call_created: originate[:event_date_gmt],
        queue_name: originate[:cc_queue],
        producer: 'dispatch_call',
        original: [left, right, originate],

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

      Log.debug "Dispatching call %p" % [msg]
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
