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
        body['display_cid'] =
          WebSocketUtils.format_display_name_and_number(body['cid_name'], body['cid_num'])
        MANAGERS.push ["#{__method__}_#{action}", body.merge(agentId: dest)]
      when cid_num
        # we're sure this is a call from user and he's the caller
        body['display_cid'] =
          WebSocketUtils.format_display_name_and_number(body['callee_name'], body['dest'])
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
      msg['id'] = msg['uuid'] || msg['call_uuid']
      say tag: 'live:Call:create', body: msg
    end

    def channel_call_update(msg)
      msg['id'] = msg['uuid'] || msg['call_uuid']
      say tag: 'live:Call:update', body: msg
    end

    def channel_call_delete(msg)
      msg['id'] = msg['uuid'] || msg['call_uuid']
      say tag: 'live:Call:delete', body: msg
    end

    def channel_call_insert(msg)
      msg['id'] = msg['uuid'] || msg['call_uuid']
      say tag: 'live:Call:insert', body: msg
    end

    def channel_call_update(msg)
      msg['id'] = msg['uuid'] || msg['call_uuid']
      say tag: 'live:Call:update', body: msg
    end

    def channel_call_delete(msg)
      msg['id'] = msg['uuid'] || msg['call_uuid']
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
      account = msg_to_account(msg)

      if TCC.options.tiny_cdr.db
        TCC::TinyCdr::Call.history(account.extension).map{|row|
          row.values.merge(start_time: row.start_stamp.utc.iso8601)
        }
      else
        TCC::CallRecord.agent_history_a(account.agent)
      end
    end

    def live_subscribe(msg)
      name = msg.fetch('name')
      log "Subscribe #{name}"

      unless @channel_name
        if @account = Account.from_call_center_name(name)
          @channel_name = MANAGERS.subscribe{|method, body|
            __send__("channel_#{method}", body)
          }
        else
          raise "#{name} doesn't have an account"
        end
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
      queues = fsr{|s| s.call_center(:tier).list(queue) }.group_by(&:queue)
      queues[queue]
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

    def live_uuid_calltap(msg)
      uuid, agent_ext = msg.fetch('uuid'), msg.fetch('agent')
      agent = Account.from_extension(agent_ext)

      return eavesdrop(uuid, agent)

      extension, name, tapper, uuid, phoneNumber = msg.values_at('extension', 'name', 'tapper', 'uuid', 'phoneNumber')

      if manager = Account.from_call_center_name(tapper)
        return false unless manager.manager?
        return false unless agent = Account.from_call_center_name(name)
        if manager.manager.authorized_to_listen?(extension, phoneNumber)
          eavesdrop(uuid, agent, manager)
        end
      end
    end

    def eavesdrop(uuid, agent)
      Log.notice("Requestion Tap of #{agent} by #{@account} -> #{uuid}")
      return false unless agent.registration_server

      Log.notice("Tapping #{agent.full_name} at #{agent.registration_server}: #{uuid}")
      sock = FSR::CommandSocket.new(:server => agent.registration_server)

      if target = @account.manager.eavesdrop_extension
      elsif @account.registration_server == agent.registration_server
        target = "user/#{@account.extension}"
      else
        target = "sofia/internal/#{@account.extension}@#{@account.registration_server}"
      end

      cmd = sock.originate(target: target, endpoint: "&eavesdrop(#{uuid})")
      Log.debug("Tap Command %p" % cmd.raw)
      cmd.run
    end

    def agent_hash(agent, all_calls)
      ext = Account.extension(agent.name)
      username = Account.full_name(agent.name)
      server = agent.contact.to_s.split('@')[1]
      calls = all_calls[server]

      agent_hash = agent.to_hash
      agent_hash[:calls] = WebSocketUtils.agent_status(ext, calls)
      agent_hash[:extension] = ext
      agent_hash[:id] = ext
      agent_hash[:username] = username
      agent_hash[:last_call_time] = agent_last_call_time(
        agent.name, ext, agent_hash[:last_bridge_end]
      )

      UTIMES.each{|key| agent_hash[key] = agent_hash[key].to_i }

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
        call_record_created_at.to_i, call_start_at.to_i,
        last_bridge_end.to_i,
        (Date.today.to_time + (8 * 60 * 60)).to_i, # 08:00
      ].compact.max
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
      log server: server
      sock = FSR::CommandSocket.new(server: server)
      cmd = yield(sock)
      log cmd.raw
      cmd.run.tap{|response| log(response) }
    ensure
      sock.socket.close if sock.respond_to?(:socket)
    end

    def msg_to_account(msg)
      account = Account.from_extension(msg.fetch('agent'))
      return account if account
      raise "No such agent: %p" % [msg['agent']]
    end
  end
end
