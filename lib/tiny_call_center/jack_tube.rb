require "em-jack"
require "json"

module TCC
  class JackTube < EMJack::Connection
    def watch_socket(tube_names)
      tube_names.each{|tube_name| watch(tube_name) }

      each_job do |job|
        Log.debug job: job
        delete(job) if handle_job(job)
      end
    end

    def handle_job(job)
      channel, payload, * = job.body.split("\t")
      type, action = channel.to_s.split("_",2)
      # action is update, insert, or delete
      # type is agent, channel, call, etc.
      if type == 'channel'
        if action == 'update'
          last_state, json = payload.split(":",2)
          body = JSON.parse(json)
          uuid = body.delete("uuid")
          channel_update uuid, last_state, body
        else
          body = JSON.parse(payload)
          uuid = body.delete("uuid")
          __send__ channel, uuid, body
        end
      else
        body = JSON.parse(payload)
        RibbonAgent.__send__("pg_#{type}", action, body)
      end
      true
    rescue => ex
      Log.error ex
      false
    end

    def channel_insert(uuid, body)
      cid_num, dest = body.values_at('cid_num', 'dest')
      return false if cid_num.nil? && dest.nil?
      Log.debug "New call #{uuid}: #{body}"
      RibbonAgent.__send__("new_call", uuid, cid_num, dest, body)
    end

    def channel_update(uuid, last_state, body)
      new_state = body["callstate"]
      Log.debug "Callstate Changed for #{uuid}: #{last_state} => #{new_state}"
      cid_num, dest = body.values_at('cid_num', 'dest')
      return false if cid_num.nil? && dest.nil?
      if ['RINGING', 'DOWN'].include?(last_state) && new_state == 'ACTIVE'
        # This is a new call
        RibbonAgent.__send__("new_call", uuid, cid_num, dest, body)
      else
        # Just an update to a call
        RibbonAgent.__send__("update_call", uuid, cid_num, dest, last_state, body)
      end
    end

    def channel_delete(uuid, body)
      Log.debug "Call Ended #{uuid}: #{body}"
      RibbonAgent.__send__("end_call", uuid, body)
    end
  end
end
