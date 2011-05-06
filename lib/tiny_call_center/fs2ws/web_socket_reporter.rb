require "tiny_call_center/utils/fsr"
module TinyCallCenter
  class WebSocketReporter < Struct.new(:reporter, :socket, :command_socket_server, :agent, :extension, :registration_server)
    include WebSocketUtils, TCC::Utils::FSR
    SubscribedAgents = {}

    def initialize(reporter, socket, command_socket_server)
      self.reporter, self.socket = reporter, socket
      self.command_socket_server = command_socket_server

      socket.onopen(&method(:on_open))
      socket.onmessage(&method(:on_message))
      socket.onclose(&method(:on_close))
    end

    def on_open
    end

    def on_fs_event(msg)
      reply msg
    end

    def on_message(json)
      msg = JSON.parse(json)

      method = "got_#{msg['method']}"
      if respond_to?(method)
        EM.defer{
          begin
            __send__(method, msg)
          rescue => e
            Log.error e
            raise
          end
        }
      else
        Log.warn "Unknown message: %p" % [msg]
      end

    rescue JSON::ParserError => ex
      Log.error ex
    end

    def got_subscribe(msg)
      self.agent = msg['agent']
      self.extension = Account.extension(agent)
      self.registration_server = Account.registration_server(extension)

      subscribe
      update_status
      update_state
      give_initial_status
    end

    def subscribe
      Log.notice "Subscribe agent: #{agent}@#{registration_server}"

      subscribed = SubscribedAgents[extension] ||= []
      subscribed << self
    end

    def update_status
      Log.debug "Set status of #{agent} to Available"
      reporter.callcenter!{|cc| cc.set(agent, :status, 'Available') }
    end

    def update_state
      return unless TCC.options.off_hook
      Log.debug "Set State of #{agent} to Idle"
      reporter.callcenter!{|cc| cc.set(agent, :state, 'Idle') }
    end

    def got_callme(msg)
      Log.info "Check whether we should call #{agent}, off_hook is #{TCC.options.off_hook}"
      return unless TCC.options.off_hook

      Log.notice "<< Calling #{agent}@#{registration_server} >>"

      command_server = TCC.options.command_server
      sock = FSR::CommandSocket.new(:server => command_server)
      FSR.load_all_commands

      orig = if registration_server == command_server
        sock.originate(
          target: "user/#{extension}",
          target_options: {tcc_agent: agent},
          endpoint: "&transfer(19999)"
        )
      else
        sock.originate(
          target: "sofia/internal/#{extension}@#{registration_server}",
          target_options: {tcc_agent: agent},
          endpoint: "&transfer(19999)"
        )
      end
      Log.info "<< #{[orig.raw, orig.run].inspect} >>"
    end

    def give_initial_status
      Log.debug "Give Initial Status"
      fsock = FSR::CommandSocket.new(server: registration_server)
      channels = fsock.channels(true).run

      channels.map do |channel|
        Log.debug channel: channel
        next unless ['ACTIVE', 'RINGING'].include?(channel.callstate) &&
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

    # TODO
    def got_disposition(msg)
      Log.notice "Got Disposition: #{msg}"
      disposition = msg.values_at('disposition')
      disp = TinyCallCenter::Disposition.find(code: msg.fetch("code"))
      unless disp
        Log.warn "Invalid disposition code #{code}"
        return
      end
      call = TinyCallCenter::CallRecord.new(disposition_id: disp.id, agent: self.agent)
      left, right = msg.fetch("left"), msg.fetch("right")

      call.update(
        left_cid_num: left["cid_number"],
        left_cid_name: left["cid_name"],
        left_destination: left["destination"],
        left_channel: left["channel"],
        left_channel: left["uuid"],
        right_cid_num: right["cid_number"],
        right_cid_name: right["cid_name"],
        right_destination: right["destination"],
        right_channel: right["channel"],
        right_channel: right["uuid"],
        queue_name: left["queue_name"] || right["queue_name"]
      )
      call.save

    rescue KeyError
      Log.warn "Invalid msg"
    end

    def got_state(msg)
      Log.debug "State Change: #{msg}"
      current, new = msg.values_at('curState', 'state')
      reporter.callcenter!{|cc| cc.set(self.agent, :state, new) }
    end

    def got_status(msg)
      Log.debug "Status Change: #{msg}"
      current, new = msg.values_at('curStatus', 'status')
      mapped = STATUS_MAPPING[new]
      reporter.callcenter!{|cc| cc.set(self.agent, :status, mapped) }
    end

    def got_hangup(msg)
      Log.debug "Hanging up: #{msg}"
      uuid, cause = msg.values_at('uuid', 'cause')
      account = Account.from_call_center_name(agent)
      sock = FSR::CommandSocket.new(:server => account.registration_server)
      cmd = sock.sched_hangup(uuid: uuid, cause: cause)
      Log.devel "<< Hangup #{cmd.raw} >>"
      res = cmd.run
      if res['body'] && res['body'] == '+OK'
        Log.devel "<< #{res} >>"
      else
        sock = FSR::CommandSocket.new(:server => TCC.options.command_server)
        cmd = sock.sched_hangup(uuid: uuid, cause: cause)
        Log.devel "<< Queue Server Hangup #{cmd.raw}>>"
        Log.devel "<< #{cmd.run}>>"
      end
    end

    def got_transfer(msg)
      Log.info "Transfer: #{msg}"
      uuid, dest = msg.values_at('uuid', 'dest')
      account = Account.from_call_center_name(agent)
      sock = FSR::CommandSocket.new(:server => account.registration_server)
      cmd = sock.sched_transfer(uuid: uuid, to: dest)
      Log.devel "<< Transfer #{cmd.raw} >>"
      res = cmd.run
      if res['body'] && res['body'] == '+OK'
        Log.devel "<< #{res} >>"
      else
        sock = FSR::CommandSocket.new(:server => TCC.options.command_server)
        cmd = sock.sched_transfer(uuid: uuid, to: dest)
        Log.devel "<< Queue Server Transfer #{cmd.raw} >>"
        Log.devel "<< #{cmd.run} >>"
      end
    end

    def got_originate(msg)
      agent, dest, identifier = msg.values_at('agent', 'dest', 'identifier')
      Log.debug "<< Originate: to: #{dest} from: #{agent} >>"
      Log.debug "<< #{originate(agent, dest, identifier).inspect} >>"
    end

    def got_dtmf(msg)
      Log.info "DTMF: #{msg}"
      uuid, dtmf = msg.values_at('uuid', 'dtmf')
      command_server = TCC.options.command_server
      sock = FSR::CommandSocket.new(:server => command_server)
      Log.info sock.uuid_send_dtmf(uuid: uuid, dtmf: dtmf).run
    end

    def on_close
      return unless subscribed = SubscribedAgents[extension]
      subscribed.delete(self)
      SubscribedAgents.delete(extension) if subscribed.empty? # slight race here.
      Log.notice "Unsubscribed agent: #{agent}"
    end
  end
end
