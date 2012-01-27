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

        AGENTS[ext].each(&block)
        found_at_least_one = true
      end

      found_at_least_one
    end

    # Eventually want to have only those sent to the ribbon.
    KEEP_CALL_KEYS = %w[
      uuid call_uuid created_epoch state cid_name cid_num dest callee_name
      callee_num secure callstate ribbon_name ribbon_number
    ]

    # don't even try to think about using direction, it's of no use.
    def self.call_dispatch(body, user, &block)
      log user: user, dest: body['dest'], cid_num: body['cid_num']
      cid_num, dest = body.values_at('cid_num', 'dest')

      body.select!{|k,v| KEEP_CALL_KEYS.include?(k) }

      format_display_name_and_number = lambda{|name, number|
        if name && number
          "#{name} (#{number})"
        elsif name
          name
        elsif number
          number
        end
      }

      case user
      when dest
        # we're sure this is a call for user and he's the receiver
        body['display_name_and_number'] =
          format_display_name_and_number.(body['cid_name'], body['cid_num'])
        each_agent(body['callee_num'], &block)
      when cid_num
        # we're sure this is a call from user and he's the caller
        body['display_name_and_number'] =
          format_display_name_and_number.(body['callee_name'], body['dest'])
        each_agent(body['cid_num'], &block)
      when 'loopback/voicemail-a'
        log 'ignore voicemail'
        # ignore voicemail
      else
        log 'unhandled call'
      end
    end

    def self.call_create(uuid, user, cid_num, dest, body)
      case body['callstate']
      when 'RINGING', 'EARLY'
        log "New Call Ringing #{uuid} (#{user}): #{cid_num} => #{dest}"
        call_dispatch(body, user){|agent| agent.pg_call_create(body) }
      when 'ACTIVE'
        log "Call Established #{uuid} (#{user}): #{cid_num} => #{dest}"
        call_dispatch(body, user){|agent| agent.pg_call_update(body) }
      else
        raise "creating callstate #{body['callstate']} not implemented"
      end
    end

    def self.call_update(uuid, user, cid_num, dest, last_call_state, last_state, body)
      call_state, state = body.values_at("callstate", "state")
      log "#{uuid} (#{user}) #{last_state}:#{last_call_state} to #{state}:#{call_state} #{cid_num} => #{dest}"

      call_dispatch(body, user){|agent| agent.pg_call_update(body) }
    end

    def self.call_delete(uuid, user, cid_num, dest, body)
      log "Call ended for #{uuid} (#{user}): #{cid_num} => #{dest}"

      call_dispatch(body, user){|agent| agent.pg_call_delete(body) }
    end

    def self.pg_agent(action, body)
      log [action, body]

      return unless ext = body['name'].to_s.split('-', 2).first
      to_delete = []
      AGENTS[ext].each do |agent|
        if peer = agent.socket.get_peername
          log "Dispatch to #{ext} #{Socket.unpack_sockaddr_in(peer).reverse.join(":")}"
          agent.__send__("pg_agent_#{action}", body)
        else
          to_delete << agent
        end
      end
      to_delete.each { |disconnected_agent| AGENTS[ext].delete(disconnected_agent) }
    end

    def self.pg_call(action, body)
      log [:call, action, body], :debug
    end

    attr_reader :socket
    # Every time a ribbon connects
    # set up the @socket and callbacks for onmessage and onclose
    def initialize(socket)
      @socket = socket
      @socket.onmessage(&method(:trigger_on_message))
      @socket.onclose(&method(:trigger_on_close))
    end

    def trigger_on_message(message)
      log("Message: %p" % {message: message}, :debug)
      raw = JSON.parse(message)
      frame, body = raw.values_at('frame', 'body')
      url, method, id, attr =
        body.values_at('url', 'method', 'id', 'attributes')

      bbm = "backbone_#{method}"
      case url
      when 'Agent'
        say tag: 'backbone', frame: frame, ok: __send__(bbm, id, attr)
      when 'Originate'
        originate(@account.extension, body['dest'], body['identifier'])
      when 'Hangup'
        hangup body['uuid'], body['cause']
      when 'Transfer'
        transfer body['uuid'], body['dest']
      when 'DTMF'
        dtmf body['uuid'], body['tone']
      else
        raise 'Unknown url %p in %p' % [url, raw]
      end

    rescue => ex
      log([ex, *ex.backtrace].join("\n"), :error)
      say tag: 'backbone', frame: frame, error: ex.to_s
    end

    def trigger_on_close
      AGENTS[@extension].delete(self)
    end

    def say(obj)
      log say: obj
      @socket.send(obj.to_json)
    end

    def dtmf(uuid, tone)
      log "DTMF: #{uuid} (#{tone})"

      command_server = TCC.options.command_server
      sock = FSR::CommandSocket.new(:server => TCC.options.command_server)
      cmd = sock.uuid_send_dtmf(uuid: uuid, dtmf: tone)
      log cmd.raw
      log cmd.run(:bgapi)
    end

    def hangup(uuid, cause)
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
      :id, :first_name, :last_name, :registration_server,
      :username, :extension
    ]

    def backbone_read(id, attributes)
      log(read: {id: id, attributes: attributes})

      if id
        @account = Account[id: id]
      else
        ext = attributes['extension']
        @account = Account[extension: ext]
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
        @account.get_queued
      end

      log "Register #{self} with #{@account.extension}"
      AGENTS[@account.extension] << self
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
