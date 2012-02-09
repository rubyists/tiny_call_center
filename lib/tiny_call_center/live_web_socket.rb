require 'json'
require 'em-websocket'
# plugin must be loaded first!
require 'sequel'
require TCC::MODEL_ROOT/:init
require_relative 'utils/fsr'
require_relative 'fs2ws/web_socket_utils'

module TCC
  class LiveManager
    include Utils::FSR, WebSocketUtils

    MANAGERS = EM::Channel.new

    def self.log(msg, level = :devel)
      Log4r::NDC.push("LiveManager")
      Log.__send__(level, msg)
      Log4r::NDC.pop
    end

    def log(msg, level = :devel)
      self.class.log(msg, level)
    end

    def log_error(ex)
      log([ex, *ex.backtrace].join("\n"), :error)
    end

    def self.format_display_name_and_number(name, number)
      name = nil unless name =~ /\S/
      number = nil unless number =~ /\S/

      if name && number
        "#{name} (#{number})"
      elsif name
        name
      elsif number
        number
      end
    end

    # Eventually want to have only those sent to the live view.
    KEEP_CALL_KEYS = %w[
      uuid call_uuid created_epoch state cid_name cid_num dest callee_name
      callee_num secure callstate ribbon_name ribbon_number queue
    ]

    # don't even try to think about using direction, it's of no use.
    def self.call(action, user, body)
      log user: user, dest: body['dest'], cid_num: body['cid_num']
      cid_num, dest = body.values_at('cid_num', 'dest')

      # body.select!{|k,v| KEEP_CALL_KEYS.include?(k) }

      case user
      when dest
        # we're sure this is a call for user and he's the receiver
        body['display_name_and_number'] =
          format_display_name_and_number(body['cid_name'], body['cid_num'])
        MANAGERS.push ["#{__method__}_#{action}", body.merge(agentId: dest)]
      when cid_num
        # we're sure this is a call from user and he's the caller
        body['display_name_and_number'] =
          format_display_name_and_number(body['callee_name'], body['dest'])
        MANAGERS.push ["#{__method__}_#{action}", body.merge(agentId: cid_num)]
      else
        log 'unhandled call'
      end
    end

    def self.call_create(uuid, user, cid_num, dest, body)
      call(:create, user, body)
    end

    def self.call_update(uuid, user, cid_num, dest, last_call_state, last_state, body)
      call_state, state = body.values_at("callstate", "state")
      log "#{uuid} (#{user}) #{last_state}:#{last_call_state} to #{state}:#{call_state} #{cid_num} => #{dest}"

      call(:update, user, body)
    end

    def self.call_delete(uuid, user, cid_num, dest, body)
      log "Call ended for #{uuid} (#{user}): #{cid_num} => #{dest}"

      call(:delete, user, body)
    end

    def self.pg_tier(action, body)
      log [__method__, action, body]
      MANAGERS.push ["tier_#{action}", body]
    end

    def self.pg_member(action, body)
      log [__method__, action, body]
      MANAGERS.push ["member_#{action}", body]
    end

    def self.pg_agent(action, body)
      log [__method__, action, body]
      MANAGERS.push ["agent_#{action}", body]
    end

    def self.pg_call(action, body)
      log [__method__, action, body]
      MANAGERS.push ["call_#{action}", body]
    end

    attr_reader :socket

    def initialize(socket)
      @socket = socket
      @socket.onmessage(&method(:trigger_on_message))
      @socket.onclose(&method(:trigger_on_close))
    end

    def on_channel(message)
      log "Channel: %p" % [message]

      say tag: 'live', body: message
    end

    def trigger_on_message(json)
      msg = JSON.parse(json)
      log("trigger_on_message: %p" % [msg], :debug)

      case msg['tag']
      when 'live'
        method_name = "live_#{msg['go']}"
        response = __send__(method_name, *[msg['body']].compact)
      end

      say tag: 'live', frame: msg['frame'], body: response
    rescue => ex
      log_error(ex)
      say tag: 'live', error: ex.to_s
    end

    def trigger_on_close
      MANAGERS.unsubscribe(@channel_name)
    end

    def say(obj)
      log say: obj
      @socket.send(obj.to_json)
    end

    def channel_call_create(msg)
      msg['id'] = msg['uuid']
      say tag: 'live:Call:create', body: msg
    end

    def channel_call_update(msg)
      msg['id'] = msg['uuid']
      say tag: 'live:Call:update', body: msg
    end

    def channel_call_delete(msg)
      msg['id'] = msg['uuid']
      say tag: 'live:Call:delete', body: msg
    end

    def channel_call_insert(msg)
      msg['id'] = msg['uuid']
      say tag: 'live:Call:insert', body: msg
    end

    def channel_call_update(msg)
      msg['id'] = msg['uuid']
      say tag: 'live:Call:update', body: msg
    end

    def channel_call_delete(msg)
      msg['id'] = msg['uuid']
      say tag: 'live:Call:delete', body: msg
    end

    def channel_agent_update(msg)
      id = msg['name'].split('-', 2)[0]
      if state = msg['state']
        say tag: 'live:Agent', body: {id: id, state: state}
      elsif status = msg['status']
        say tag: 'live:Agent', body: {id: id, status: status}
      end
    end

    def live_agent_status(msg)
      msg_to_account(msg).status = msg.fetch('status')
    end

    def live_agent_state(msg)
      msg_to_account(msg).state = msg.fetch('state')
    end

    def live_agent_status_log(msg)
      return [] unless TCC.options.mod_callcenter.db
      account = msg_to_account(msg)
      TCC::CallCenter::StatusLog.agent_history_a(account.agent)
    end

    def live_agent_state_log(msg)
      return [] unless TCC.options.mod_callcenter.db
      account = msg_to_account(msg)
      TCC::CallCenter::StateLog.agent_history_a(account.agent)
    end

    def live_agent_call_log(msg)
    end

    def got_agent_call_history(msg)
      account = msg_to_account(msg)

      if TCC.options.tiny_cdr.db
        TCC::TinyCdr::Call.history(account.extension).map{|row|
          row.values.merge(start_time: row.start_stamp.rfc2822)
        }
      else
        TCC::CallRecord.agent_history_a(account.agent)
      end
    end

    def live_subscribe(msg)
      log msg
      name = msg.fetch('name')
      log "Subscribe #{name}"

      unless @channel_name
        @channel_name = MANAGERS.subscribe{|method, body|
          __send__("channel_#{method}", body)
        }
      end

      {subscribed: true}
    end

    def live_queues
      all = fsr{|s| s.call_center(:queue).list }
      queues = all.select{|queue| queue.name !~ /_dialer$/ }
      {queues: queues}
    end

    def live_queue_agents(msg)
      queue = msg.fetch('queue')
      fsr{|s| s.call_center(:tier).list(queue) }.group_by(&:queue)
    end

    UTIMES = %w[last_bridge_start last_offered_call last_bridge_end last_status_change]

    def live_agents
      agents = fsr{|s| s.call_center(:agent).list }
      agents_with_contact, agents_without_contact = agents.partition{|agent| agent.contact }

      if agents_without_contact.any?
        log "Found agents without contact:"
        log agents_without_contact.map(&:name)
      end

      # select agents the manager can view
      # for testing i'm cutting that out
      calls = agent_calls(agents_with_contact)

      {agents: agents_with_contact.map{|agent| agent_hash(agent, calls) }}
    end

    def agent_hash(agent, all_calls)
      ext = Account.extension(agent.name)
      username = Account.full_name(agent.name)
      server = agent.contact.to_s.split('@')[1]
      calls = all_calls[server]

      agent_hash = agent.to_hash
      agent_hash[:calls] = agent_status(ext, calls)
      agent_hash[:extension] = ext
      agent_hash[:id] = ext
      agent_hash[:username] = username
      agent_hash[:last_call_time] = agent_last_call_time(
        agent.name, ext, agent_hash[:last_bridge_end]
      )

      UTIMES.each{|key| agent_hash[key] = Time.at(agent_hash[key].to_i).rfc2822 }

      agent_hash
    end

    def agent_last_call_time(name, ext, last_bridge_end)
      if call_record = CallRecord.last(name)
        call_record_created_at = call_record.created_at
      end

      if TCC.options.tiny_cdr.db
        if call = TCC::TinyCdr::Call.last(ext)
          call_start_at = call.start_stamp
        end
      end

      last_call_time = [
        call_record_created_at, call_start_at,
        Time.at(last_bridge_end.to_i),
        Date.today.to_time + (8 * 60 * 60), # 08:00
      ].compact.max.rfc2822
    end

    def agent_calls(agents)
      calls = {}

      agents.map{|agent| agent.contact.split('@', 2)[1] }.uniq.
        each do |agent_server|
        begin
          calls[agent_server] = fsr(agent_server){|s| s.channels(true) }
        rescue Errno::ECONNREFUSED => e
          log "Registration Server #{agent_server} not found", :error
          log_error(e)
        end
      end

      calls
    end

    private

    # TODO: allow safe reuse of socket
    def fsr(server = TCC.options.command_server)
      sock = FSR::CommandSocket.new(server: server)
      cmd = yield(sock)
      log cmd.raw
      cmd.run.tap{|response| log(response) }
    ensure
      sock.socket.close
    end

    def msg_to_account(msg)
      account = Account[extension: msg.fetch('agent')]
      return account if account
      raise "No such agent: %p" % [ext]
    end
  end
end
