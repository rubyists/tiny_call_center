module TinyCallCenter
  class WebSocketReporter < Struct.new(:reporter, :socket, :command_socket_server, :agent, :extension, :registration_server)
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
      self.extension = Account.extension(agent)
      self.registration_server = Account.registration_server(extension)

      subscribe
      update_status
      update_state
      calls = give_initial_status
      call unless calls.detect { |c|
        [c[:left][:cid_number],  c[:right][:cid_number]].include? '8675309'
      }
    end

    def subscribe
      FSR::Log.info "Subscribe agent: #{agent}@#{registration_server}"

      subscribed = SubscribedAgents[extension] ||= []
      subscribed << self
    end

    def update_status
      FSR::Log.debug "Set status of #{agent} to Available"
      reporter.callcenter!{|cc| cc.set(agent, :status, 'Available') }
    end

    def update_state
      FSR::Log.debug "Set State of #{agent} to Idle"
      reporter.callcenter!{|cc| cc.set(agent, :state, 'Idle') }
    end

    def call
      FSR::Log.debug "Check whether we should call #{agent}, off_hook is #{TCC.options.off_hook}"
      return unless TCC.options.off_hook
      EM.add_timer 5 do
        FSR::Log.info "Calling #{agent}@#{registration_server}"

        command_server = TCC.options.command_server
        sock = FSR::CommandSocket.new(:server => command_server)
        FSR.load_all_commands

        if registration_server == command_server
          sock.originate(
            target: "{tcc_agent=#{agent}}user/#{extension}",
            endpoint: "&transfer(19999)"
          ).run
        else
          sock.originate(
            target: "{tcc_agent=#{agent}}sofia/internal/#{extension}@#{registration_server}",
            endpoint: "&transfer(19999)"
          ).run
        end
      end
    end

    def give_initial_status
      FSR::Log.debug "Give Initial Status"
      fsock = FSR::CommandSocket.new(server: registration_server)
      channels = fsock.channels(true).run

      channels.map do |channel|
        FSR::Log.debug channel: channel
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
      reporter.callcenter!{|cc| cc.set(self.agent, :state, new) }
    end

    def got_status(msg)
      FSR::Log.debug "Status Change: #{msg}"
      current, new = msg.values_at('curStatus', 'status')
      mapped = STATUS_MAPPING[new]
      reporter.callcenter!{|cc| cc.set(self.agent, :status, mapped) }
    end

    def on_close
      subscribed = SubscribedAgents[extension]
      subscribed.delete(self)
      SubscribedAgents.delete(extension) if subscribed.empty? # slight race here.
      FSR::Log.debug "Unsubscribed agent: #{agent}"
    end
  end
end
