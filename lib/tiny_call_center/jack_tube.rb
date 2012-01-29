require "em-jack"
require "json"

module TCC
  class JackTube < EMJack::Connection
    INTERFACES = [RibbonAgent]

    # change this to :devel to see most messages here (anything without a loglevel as the second arg)
    def log(msg, level = :devel)
      Log4r::NDC.push("jack_tube")
      Log.__send__(level, msg)
      Log4r::NDC.pop
    end

    def watch_socket(tube_names)
      tube_names.each{|tube_name| watch(tube_name) }

      each_job do |job|
        log({job: job}, :debug)
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
          last_call_state, last_state, json = payload.split(":",3)
          body = JSON.parse(json)
          uuid = body["uuid"]
          channel_update uuid, last_call_state, last_state, body
        else
          body = JSON.parse(payload)
          uuid = body["uuid"]
          __send__ channel, uuid, body
        end
      else
        body = JSON.parse(payload)
        INTERFACES.each { |interface| interface.__send__("pg_#{type}", action, body) }
      end
      true
    rescue => ex
      log ex, :error
      log ex.backtrace.join("\n"), :error
      false
    end

    def channel_insert(uuid, body)
      cid_num, dest, name = body.values_at('cid_num', 'dest', 'name')
      if name =~ %r{/(?:sip:)?(\d+)@[^/]*$}
        user = $1
      else
        user = name
      end
      return false if user =~ %r{^loopback/(\w+)-b$}
      if user =~ %r{^loopback/(\d+)-a$}
        user = $1
      end
      log "New channel #{uuid}: #{name}"
      return false if cid_num.nil? && dest.nil?
      INTERFACES.each { |interface| interface.call_create(uuid, user, cid_num, dest, body) }
    end

    def channel_update(uuid, last_call_state, last_state, body)
      cid_num, dest, name, new_call_state, new_state = body.values_at('cid_num', 'dest', 'name', 'callstate', 'state')
      if name =~ %r{/(?:sip:)?(\d+)@[^/]*$}
        user = $1
      else
        user = name
      end
      log "#{uuid}: #{last_state}:#{last_call_state} => #{new_state}:#{new_call_state} - #{cid_num} => #{dest}"
      return false if user == 'loopback/voicemail-b'
      return false if cid_num.nil? && dest.nil?
      return false if new_call_state == last_call_state
      if new_call_state == 'ACTIVE' || last_call_state != 'EARLY'
        # This is a new call,
        INTERFACES.each { |interface| interface.call_create(uuid, user, cid_num, dest, body) }
      elsif new_call_state == 'EARLY'
        INTERFACES.each { |interface| interface.call_create(uuid, user, cid_num, dest, body) }
      else
        # Just an update to a call (HELD, ACTIVE, EARLY, RINGING, others?)
        INTERFACES.each { |interface| interface.call_update(uuid, user, cid_num, dest, last_call_state, last_state, body) }
      end
    end

    def channel_delete(uuid, body)
      cid_num, dest, name = body.values_at('cid_num', 'dest', 'name')
      if name =~ %r{/(?:sip:)?(\d+)@[^/]*$}
        user = $1
      else
        user = name
      end
      return false if user == 'loopback/voicemail-b'
      log "Call Ended #{uuid}: #{body}", :debug
      INTERFACES.each { |interface| interface.call_delete(uuid, user, cid_num, dest, body) }
    end
  end
end
