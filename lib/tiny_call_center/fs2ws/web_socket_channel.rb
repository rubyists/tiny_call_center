module TinyCallCenter
  class WebSocketChannel < Struct.new(:reporter, :socket, :command_socket_server, :user, :agent, :channel_id)
    include WebSocketUtils, ChannelRelay
    Channel = EM::Channel.new

    def initialize(reporter, socket, command_socket_server)
      self.reporter, self.socket = reporter, socket
      self.command_socket_server = command_socket_server

      socket.onopen(&method(:on_open))
      socket.onmessage(&method(:on_message))
      socket.onclose(&method(:on_close))
    end

    def on_open
      self.channel_id = Channel.subscribe{|message|
        reply(message) if can_view?(message)
      }
    end

    def on_close
      Channel.unsubscribe(channel_id)
      FSR::Log.debug "Unsubscribed listener: #{agent}"
    end

    def on_message(json)
      msg = JSON.parse(json)

      case msg['method']
      when 'subscribe' ; got_subscribe(msg)
      when 'calltap'   ; got_calltap(msg)
      when 'status_of' ; got_status_of(msg)
      when 'calltaptoo'; got_calltap_too(msg)
      else
        FSR::Log.warn "Unknown message: %p" % [msg]
      end
    rescue JSON::ParserError => ex
      FSR::Log.error ex
    end

    def agent_listing
      sock = fsr_socket(self.command_socket_server)
      agents = sock.call_center(:agent).list.run
      sock.socket.close
      agents
    end

    def got_subscribe(msg)
      self.agent = msg['agent']
      FSR::Log.info "Subscribing listener: #{self.agent}"

      self.user = TinyCallCenter::Account.from_call_center_name(agent) # everything regarding perms in Account
      FSR::Log.info "User #{user} subscribed"

      agents = agent_listing
      if user.manager?
        agents.select! {|_agent| user.can_view?(_agent.extension) }
        FSR::Log.info "#{user} can view #{agents.size} agents"
      else
        # if somehow an agent got here, just show them themselves
        FSR::Log.info "User #{user} not a manager, showing just self"
        agents.select! {|_agent| self.agent == _agent.name }
      end

      servers = {}
      registrars = agents.map {|_agent| _agent.to_hash["contact"].split("@")[1] }.uniq
      registrars.each do |r|
        fsock = FSR::CommandSocket.new server: r
        servers[r] = fsock.channels(true).run
        fsock.socket.close
        fsock = nil
      end

      utimes = %w[last_bridge_start last_offered_call last_bridge_end last_status_change]
      agents.map!{|_agent|
        agent_ext = _agent.name.split('-').first
        agent_server = _agent.contact.to_s.split('@')[1]
        agent_calls = servers[agent_server]
        _agent = _agent.to_hash.merge(agent_status(agent_ext, agent_calls))
        utimes.each{|key|
          _agent[key] = Time.at(_agent[key].to_i).rfc2822
        }
        _agent
      }

      reply agents: agents
    end

    def can_view?(message)
      FSR::Log.debug("#{agent} Asking for access to #{message}")

      return false unless agent

      self.user ||= TinyCallCenter::Account.from_call_center_name(agent)
      return false unless user && user.extension

      if cc = message[:cc_agent]
        extension = cc.split("-")[0].tr("_", "")
        FSR::Log.debug("#{user} has user extension #{user.extension} and extension #{extension} cc is #{cc}")
        return true if cc == agent
        return user.extension == extension || user.can_view?(extension)
      end

      numbers = possible_numbers(message)
      unless numbers.size > 1
        FSR::Log.warn("#{agent} Asking for access to crazysauce: #{message}")
        return true
      end

      FSR::Log.debug("#{agent} Asking for access to #{numbers}")
      return true if numbers.detect{|number| number.size == 4 && user.can_view?(number) }

      FSR::Log.debug("#{agent} DENIED access to: #{numbers}")
      false
    end

    def got_calltap_too(msg)
      extension, name, tapper, uuid, phoneNumber = msg.values_at('extension', 'name', 'tapper', 'uuid', 'phoneNumber')
      if manager = TinyCallCenter::Account.from_call_center_name(tapper)
        return false unless manager.manager?
        return false unless agent = TinyCallCenter::Account.from_full_name(name)
        if manager.manager.authorized_to_listen?(extension, phoneNumber)
          eavesdrop(uuid, agent, manager)
        end
      end
    end

    def got_calltap(msg)
      agent, tapper = msg.values_at('agent', 'tapper').map { |a| TinyCallCenter::Account.new(a.split("-",2)[1].gsub("_","")) }
      return false unless agent.exists? and tapper.exists?
      return false unless tapper.manager?
      if (sock = FSR::CommandSocket.new(:server => agent.registration_server) rescue nil)
        res = sock.say("api hash select/#{agent.registration_server}-spymap/#{agent.extension}")
        if uuid = res["body"]
          eavesdrop(uuid, agent, tapper)
        end
      end
    end

    def eavesdrop(uuid, agent, tapper)
      return false unless agent.registration_server
      FSR::Log.info("Tapping #{agent.full_name} at #{agent.registration_server}: #{uuid}")
      if (sock = FSR::CommandSocket.new(:server => agent.registration_server) rescue nil)
        if eavesdrop_extension = tapper.manager.eavesdrop_extension
          cmd = sock.originate(:target => eavesdrop_extension, :endpoint => "&eavesdrop(#{uuid})")
        elsif tapper.registration_server == agent.registration_server
          cmd = sock.originate(:target => "user/#{tapper.extension}", :endpoint => "&eavesdrop(#{uuid})")
        else
          cmd = sock.originate(:target => "sofia/internal/#{tapper.extension}@#{tapper.registration_server}", :endpoint => "&eavesdrop(#{uuid})")
        end
        FSR::Log.info("Tap Command %s" % cmd.raw)
        p cmd.run
      end
    end
  end
end
