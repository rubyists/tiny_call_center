require 'json'
require 'em-websocket'
# plugin must be loaded first!
require 'sequel'
Sequel::Model.plugin :json_serializer
require TCC::MODEL_ROOT/:init

require_relative 'utils/fsr'

module TCC
  class RibbonAgent
    include Utils::FSR

    AGENTS = Hash.new{|h,k| h[k] = [] }

    def self.log(msg, level = :devel)
      Log4r::NDC.push("ribbon")
      Log.__send__(level, msg)
      Log4r::NDC.pop
    end

    def log(msg, level = :devel)
      self.class.log(msg, level)
    end


    def self.each_agent(*exts, &block)
      found_at_least_one = false

      exts.flatten.uniq.compact.each do |ext|
        next unless AGENTS.key?(ext)

        log "Sending to #{ext}"
        AGENTS[ext].each(&block)
        found_at_least_one = true
      end

      found_at_least_one
    end

    # Eventually want to have only those sent to the ribbon.
    KEEP_CALL_KEYS = %w[
      uuid created_epoch state cid_name cid_num dest callee_name
      callee_num secure callstate queue display_cid
    ]

    # don't even try to think about using direction, it's of no use.
    def self.call_dispatch(body, user, &block)
      log body
      cid_num, dest = body.values_at('cid_num', 'dest')

      body.select!{|k,v| KEEP_CALL_KEYS.include?(k) }

      case user
      when dest
        # user is callee
        body['display_cid'] = Utils::FSR.format_display_name_and_number(
          body.fetch('cid_name'), body.fetch('cid_num'))
        body['id'] = body.fetch('uuid')
        each_agent(dest, &block)
      when cid_num
        # user is caller
        body['display_cid'] = Utils::FSR.format_display_name_and_number(
          body.fetch('callee_name'), body.fetch('dest'))
        body['id'] = body.fetch('uuid')
        each_agent(cid_num, &block)
      else
        log 'unhandled call'
      end
    end

    def self.call_create(uuid, user, cid_num, dest, body)
      call_dispatch(body, user){|agent| agent.call_create(body) }
    end

    def self.call_update(uuid, user, cid_num, dest, last_call_state, last_state, body)
      call_state, state = body.values_at("callstate", "state")
      log "#{uuid} (#{user}) #{last_state}:#{last_call_state} to #{state}:#{call_state} #{cid_num} => #{dest}"

      call_dispatch(body, user){|agent| agent.call_update(body) }
    end

    def self.call_delete(uuid, user, cid_num, dest, body)
      log "Call ended for #{uuid} (#{user}): #{cid_num} => #{dest}"

      call_dispatch(body, user){|agent| agent.call_delete(body) }
    end

    def self.pg_tier(action, body)
      log pg_tier: [action, body]
    end

    def self.pg_member(action, body)
      log pg_member: [action, body]
    end

    def self.pg_call(action, body)
      log pg_call: [action, body]
    end

    def self.pg_agent(action, body)
      log pg_agent: [action, body]

      return unless ext = body['name'].to_s.split('-', 2).first
      to_delete = []
      AGENTS[ext].each do |agent|
        if peer = agent.socket.get_peername
          log "Dispatch to #{ext} #{Socket.unpack_sockaddr_in(peer).reverse.join(":")}"
          agent.__send__("agent_#{action}", body)
        else
          to_delete << agent
        end
      end
      to_delete.each { |disconnected_agent| AGENTS[ext].delete(disconnected_agent) }
    end

    attr_reader :socket

    # Every time a ribbon connects
    # set up the @socket and callbacks for onmessage and onclose
    def initialize(socket)
      @socket = socket
      @socket.onmessage(&method(:trigger_on_message))
      @socket.onclose(&method(:trigger_on_close))
    end

    def trigger_on_message(json)
      msg = JSON.parse(json)
      log "-"
      log msg

      case msg.fetch('tag')
      when 'ribbon'
        method_name = "ribbon_#{msg.fetch('go')}"
        response = __send__(method_name, *[msg['body']].compact)
      end

      say tag: 'ribbon', frame: msg.fetch('frame'), body: response
    rescue => ex
      log_error(ex)
      say tag: 'ribbon', error: ex.to_s
    end

    def trigger_on_close
      AGENTS[@extension].delete(self)
    end

    def say(obj)
      log say: obj
      @socket.send(obj.to_json)
    end

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

    def status=(new_status)
      log "set status of #{@account.agent} to #{new_status}"
      FSListener.execute TCC.options.command_server do |listener|
        listener.callcenter!{|cc| cc.set(@account.agent, :status, new_status) }
      end
    end

    def state=(new_state)
      log "set state of #{@account.agent} to #{new_state}"
      FSListener.execute TCC.options.command_server do |listener|
        listener.callcenter!{|cc| cc.set(@account.agent, :state, new_state) }
      end
    end

    def call_me
      return unless TCC.options.off_hook

      agent = @account.agent
      registration_server = @account.registration_server
      extension = @account.extension

      command_server = TCC.options.command_server
      sock = FSR::CommandSocket.new(:server => command_server)

      if registration_server == command_server 
        target = "user/#{extension}" 
      else
        target = "sofia/internal/#{extension}@#{registration_server}"
      end

      cmd = sock.originate(target: target, target_options: {tcc_agent: agent}, endpoint: "&transfer(19999)")
      log cmd.raw
      log cmd.run
    end

    def give_initial_status
      log "Give initial status"
      agent_name = @account.agent
      sock = FSR::CommandSocket.new(server: TCC.options.command_server)
      agent = sock.call_center(:agent).list.run.find{|a| a.name == agent_name }
      channels = fsr(@account.registration_server){|socket| socket.channels(true) }
      calls = WebSocketUtils.agent_status(@account.extension, channels)
      calls.uniq(&:uuid)
      say tag: 'ribbon:initialStatus', body: {
        agent: {status: agent.status, state: agent.state, uuid: agent.uuid},
        calls: calls,
      }
    end

    def ribbon_subscribe(msg)
      log subscribe: msg

      @account = Account.from_call_center_name(msg.fetch('agent'))
      log "Register Ribbon for #{@account.agent}"
      AGENTS[@account.extension] << self

      give_initial_status

      self.status = 'Available'

      if TCC.options.off_hook
        self.state = 'Waiting'
        # call_me
      end
    end

    def ribbon_call_me
      call_me
    end

    def ribbon_status(msg)
      self.status = msg.fetch('status')
    end

    def ribbon_state(msg)
      self.state = msg.fetch('state')
    end

    def ribbon_hangup(msg)
      uuid, cause = msg.fetch('uuid'), msg.fetch('cause')
      log "Hanging up: #{uuid} (#{cause})"

      sock = FSR::CommandSocket.new(:server => @account.registration_server)
      cmd = sock.sched_hangup(uuid: uuid, cause: cause)

      log "Hangup #{cmd.raw}"

      res = cmd.run

      if res['body'] && res['body'] == '+OK'
        log res
      else
        sock = FSR::CommandSocket.new(:server => TCC.options.command_server)
        cmd = sock.sched_hangup(uuid: uuid, cause: cause)
        log "Queue Server Hangup #{cmd.raw}"
        log cmd.run
      end
    end

    def agent_create(msg)
    end

    def agent_update(msg)
      say tag: 'ribbon:Agent:update', body: msg
    end

    def agent_delete(msg)
    end

    def call_create(call)
      log call_create: call
      say tag: 'ribbon:Call:create', body: call
    end

    def call_update(call)
      log call_update: call
      say tag: 'ribbon:Call:update', body: call
    end

    def call_delete(call)
      log call_delete: call
      say tag: 'ribbon:Call:delete', body: call
    end
  end
end

__END__

    def disposition(uuid, code, desc)
      log disposition: [uuid, code, desc]
    end

    def dtmf(uuid, tone)
      log "DTMF: #{uuid} (#{tone})"

      command_server = TCC.options.command_server
      sock = FSR::CommandSocket.new(:server => TCC.options.command_server)
      cmd = sock.uuid_send_dtmf(uuid: uuid, dtmf: tone)
      log cmd.raw
      log cmd.run(:bgapi)
    end


    def transfer(uuid, dest)
      log "Transfer #{uuid} => #{dest}"

      sock = FSR::CommandSocket.new(:server => @account.registration_server)
      cmd = sock.sched_transfer(uuid: uuid, to: dest)

      log "Transfer #{cmd.raw}"

      res = cmd.run

      if res['body'] && res['body'] == '+OK'
        log res
      else
        sock = FSR::CommandSocket.new(:server => TCC.options.command_server)
        cmd = sock.sched_transfer(uuid: uuid, to: dest)
        log "Queue Server Transfer #{cmd.raw}"
        log "#{cmd.run}"
      end
    end

    EXPOSE = [
      :first_name, :last_name, :registration_server, :username, :extension
    ]

    def backbone_read(id, attributes)
      log(read: {id: id, attributes: attributes})

      if id
        @account = Account[id: id]
      else
        ext = attributes['extension']
        @account = Account.from_extension(ext)
      end

      raise 'no account found' unless @account

      agent_connected

      JSON.parse(@account.to_json(naked: true, only: EXPOSE))
    end

    def agent_connected
      @account.status = 'Logged Out'
      @account.status = 'Available'

      # # TODO: might not work
      if TCC.options.off_hook
        @account.state = 'Idle'
        @account.state = 'Waiting'
        call_me
      end

      log "Register Ribbon for #{@account.extension}"
      AGENTS[@account.extension] << self
    end


    def give_initial_status
      Log.debug "Give Initial Status"
      fsock = FSR::CommandSocket.new(server: registration_server)
      channels = fsock.channels(true).run

      channels.map do |channel|
        Log.debug channel: channel
        next unless ['ACTIVE', 'EARLY', 'RINGING'].include?(channel.callstate) &&
          (channel.dest == extension ||
           channel.cid_num == extension ||
           channel.name =~ /(^\/)#{extension}[@-]/)

        msg = {
          tiny_action: 'call_start',
          call_created: Time.at(channel.created_epoch.to_i).rfc2822,
          producer: 'give_initial_status',
          original: channel,

          left: {
            cid_number:  channel.cid_num,
            cid_name:    channel.cid_name,
            channel:     channel.name,
            destination: channel.dest,
            uuid:        channel.uuid,
          },
          right: {
            cid_number:  channel.cid_num,
            cid_name:    channel.cid_name,
            destination: channel.dest,
            uuid:        channel.uuid,
          }
        }

        reply msg
        msg
      end.compact
    end

    def pg_call_create(body)
      log "create call #{body}"
      say tag: 'pg', kind: 'call_create', body: body
    end

    def pg_call_delete(body)
      log "delete call #{body}"
      say tag: 'pg', kind: 'call_delete', body: body
    end

    def pg_call_update(body)
      log "update call #{body}"
      say tag: 'pg', kind: 'call_update', body: body
    end

    # These will be sent as messages from beanstalk
    def pg_agent_create(body)
      log "create #{body}"
      # that won't happen
      say tag: 'pg', kind: 'agent_create', body: body
    end
    alias pg_agent_insert pg_agent_create

    def pg_agent_update(body)
      log "update #{body}"
      say tag: 'pg', kind: 'agent_update', body: body
    end

    def pg_agent_delete(body)
      log "delete #{body}"
      # well, what on earth are we supposed to do?
      say tag: 'pg', kind: 'agent_delete', body: body
    end

    # These are messages from backbone
    def backbone_create(*args)
      log [:backbone_create, args]
      raise 'wtf'
    end

    # FIXME: need persistent account object?
    def backbone_update(id, attributes)
      log [:backbone_update, id, attributes]

      if account = Account[id: id]
        account.update(attributes)
        return(attributes)
      else
        raise "No account"
      end
    end

    def backbone_delete(*args)
      log [:backbone_delete, args]
      raise 'wtf'
    end
  end
end
