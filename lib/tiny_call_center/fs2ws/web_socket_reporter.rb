module TinyCallCenter
  class WebSocketReporter < Struct.new(:reporter, :socket, :command_socket_server, :agent)
    include WebSocketUtils
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

      case msg['method']
      when 'subscribe'; got_subscribe(msg)
      when 'status'; got_status(msg)
      when 'state'; got_state(msg)
      when 'disposition'; got_disposition(msg)
      else
        FSR::Log.warn "Unknown message: %p" % [msg]
      end
    rescue JSON::ParserError => ex
      FSR::Log.error ex
    end

    def got_subscribe(msg)
      self.agent = msg['agent']
      FSR::Log.info "Subscribed agent: #{self.agent}"
      reporter.callcenter!{|cc| cc.set(self.agent, :status, 'Available') }
      reporter.callcenter!{|cc| cc.set(self.agent, :state, 'Idle') }

      @extension = self.agent.split('-', 2).first

      subscribed = SubscribedAgents[@extension] ||= []
      subscribed << self

      fsock = FSR::CommandSocket.new server: Account.registration_server(@extension)
      channels = fsock.channels(true).run

      channels.each do |channel|
        FSR::Log.debug channel: channel
        next unless channel.callstate == 'ACTIVE' &&
          (channel.dest == @extension ||
           channel.cid_num == @extension ||
           channel.name =~ /(^\/)#{@extension}@/)

        msg = {
          tiny_action: 'call_start',
          call_created: Time.at(channel.created_epoch.to_i).rfc2822,

          left: {
            cid_number:  channel.cid_num,
            cid_name:    channel.cid_name,
            channel:     channel.name,
            destination: channel.dest,
            uuid:        channel.uuid,
          },
          right: {
            destination: channel.dest,
            uuid:        channel.uuid,
          }
        }

        FSR::Log.debug "Sending message #{msg}"
        reply msg
      end
    end

    # TODO
    def got_disposition(msg)
      FSR::Log.info "Got Disposition: #{msg}"
      disposition = msg.values_at('disposition')
      disp = TinyCallCenter::Disposition.find(code: msg.fetch("code"))
      unless disp
        FSR::Log.warn "Invalid disposition code #{code}"
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
      FSR::Log.warn "Invalid msg"
    end

    def got_state(msg)
      FSR::Log.debug "State Change: #{msg}"
      current, new = msg.values_at('curState', 'state')
      mapped = STATE_MAPPING[new]
      if current == mapped or mapped == @_last_state
        FSR::Log.warn "Got a dupe state request #{self.agent}: #{msg}"
        return false
      end
      @_last_state = mapped
      reporter.callcenter!{|cc| cc.set(self.agent, :state, mapped) }
    end

    def got_status(msg)
      FSR::Log.debug "Status Change: #{msg}"
      current, new = msg.values_at('curStatus', 'status')
      mapped = STATUS_MAPPING[new]
      if current == mapped or mapped == @_last_status
        FSR::Log.warn "Got a dupe status request #{self.agent}: #{msg}"
        return false
      end
      @_last_status = mapped
      reporter.callcenter!{|cc| cc.set(self.agent, :status, mapped) }
    end

    def on_close
      subscribed = SubscribedAgents[@extension]
      subscribed.delete(self)
      SubscribedAgents.delete(@extension) if subscribed.empty? # slight race here.
      FSR::Log.debug "Unsubscribed agent: #{agent}"
    end
  end
end
