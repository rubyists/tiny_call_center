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
        if can_view?(message)
          Log.debug "<< Relaying #{message} to channel for #{agent} >>"
          reply(message)
        else
          Log.debug "<< Relaying failed in can_view for (#{agent}) to channel >>"
          Log.debug "<< #{message}) >>"
        end
      }
    end

    def on_close
      Channel.unsubscribe(channel_id)
      Log.notice "Unsubscribed listener: #{agent}"
    end

    def on_message(json)
      msg = JSON.parse(json)

      method = "got_#{msg['method']}"

      if respond_to?(method)
        send(method, msg)
      else
        Log.warn "Unknown message: %p" % [msg]
      end
    rescue JSON::ParserError => ex
      Log.error ex
    end

    def agent_listing
      sock = fsr_socket(self.command_socket_server)
      agents = sock.call_center(:agent).list.run
      sock.socket.close
      agents
    end

    def got_subscribe(msg)
      self.agent = msg['agent']
      Log.notice "Subscribing listener: #{self.agent}"

      # everything regarding perms in Account
      self.user = Account.from_call_center_name(agent)
      Log.notice "User #{user} subscribed"

      give_agent_listing
      give_queues
    end

    def got_status_of(msg)
      mapped = STATUS_MAPPING[msg['status']]
      agent = msg['agent']
      reporter.callcenter!{|cc| cc.set(agent, :status, mapped) }
    end

    def got_state_of(msg)
      agent = msg['agent']
      reporter.callcenter!{|cc| cc.set(agent, :state, msg['state']) }
    end

    def got_agents_of(msg)
      queue_names = [msg["queue"], msg["queues"]].flatten.compact
      sock = fsr_socket(self.command_socket_server)
      queue_names.each do |queue_name|
        tiers = sock.call_center(:tier).list(queue_name).run.select{|tier| can_view?(cc_agent: tier.agent) }
        reply method: :agents_of, args: [queue_name, tiers]
      end
    end

    def give_queues
      sock = fsr_socket(self.command_socket_server)
      queues = sock.call_center(:queue).list.run
      reply method: :queues, args: [queues]
    end

    def give_agent_listing
      agents = agent_listing
      if user.manager?
        agents.select! {|agent| user.can_view?(agent.extension) }
        Log.debug "#{user} can view #{agents.size} agents"
      else
        # if somehow an agent got here, just show them themselves
        Log.warn "User #{user} not a manager, showing just self"
        agents.select! {|agent| self.agent == agent.name }
      end

      servers = {}
      registrars = agents.map {|agent| agent.contact.split("@")[1] }.uniq
      registrars.each do |r|
        begin
          fsock = FSR::CommandSocket.new server: r
          servers[r] = fsock.channels(true).run
          fsock.socket.close
          fsock = nil
        rescue Errno::ECONNREFUSED => e
          Log.error "Registration Server #{r} not found"
        end
      end

      utimes = %w[last_bridge_start last_offered_call last_bridge_end last_status_change]
      agents.map!{|agent|
        agent_ext = Account.extension(agent.name)
        agent_username = Account.full_name(agent.name)
        agent_server = agent.contact.to_s.split('@')[1]
        agent_calls = servers[agent_server]

        agent_hash = agent.to_hash
        agent_hash.merge!(calls: agent_status(agent_ext, agent_calls))
        agent_hash.merge!(extension: agent_ext, username: agent_username)

        if cr = CallRecord.last(agent.name)
          cr_at = cr.created_at
        end
        if TCC.options.tiny_cdr.db
          tiny_call = TCC::TinyCdr::Call.last(agent_ext)
          tc_at = tiny_call.start_stamp if tiny_call
        end
        last_call_time = [
          tc_at,
          cr_at,
          Time.at(agent_hash['last_bridge_end'].to_i),
          Date.today.to_time + (8 * 60 * 60), # 08:00
        ].compact.max
        agent_hash.merge!(last_call_time: last_call_time.rfc2822)

        utimes.each{|key| agent_hash[key] = Time.at(agent_hash[key].to_i).rfc2822 }
        WebSocketReporter::SubscribedAgents[agent_ext] ||= [agent.name]
        agent_hash
      }

      reply method: :agent_list, args: [agents]
    end

    def can_view?(message)
      unless agent
        Log.debug "<<< can_view? failure >>>"
        Log.debug "No agent found. Message: #{message}"
        return false
      end

      self.user ||= Account.from_call_center_name(agent)
      unless user && user.extension
        Log.debug "<<< can_view? failure >>>"
        Log.debug "'user': (#{user}) or 'user.extension': (#{user.extension}) is nil"
        return false
      end

      if cc = message[:cc_agent]
        extension = Account.extension cc
        Log.debug("#{user} has user extension #{user.extension} and extension #{extension} cc is #{cc}")
        return true if cc == agent
        return user.extension == extension || user.can_view?(extension)
      end

      numbers = possible_numbers(message)
      unless numbers.size > 1
        Log.debug "%p Asking for access to crazysauce: %p" % [agent, message]
        return false
      end

      Log.debug "%p asking for access to %p" % [user, numbers]
      return true if numbers.detect{|number| number.size == 4 && user.can_view?(number) }

      Log.debug "%p denied access to %p" % [user, numbers]
      false
    end

    def got_calltap_too(msg)
      extension, name, tapper, uuid, phoneNumber = msg.values_at('extension', 'name', 'tapper', 'uuid', 'phoneNumber')
      if manager = Account.from_call_center_name(tapper)
        return false unless manager.manager?
        return false unless agent = Account.from_call_center_name(name)
        if manager.manager.authorized_to_listen?(extension, phoneNumber)
          eavesdrop(uuid, agent, manager)
        end
      end
    end

    def got_calltap(msg)
      agent, tapper = msg.values_at('agent', 'tapper').map { |a| 
        if Account.respond_to? :find
          # If your Account backend responds to #find, we expect
          # that you define a #username function to get the username from
          # 1234-First_Last
          Account.find(username: Account.username(a)) 
        else
          # If your Account model doesn't respond to #find, we expect
          # #new to take a username
          Account.new(Account.username a) 
        end
      }

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
      Log.notice("Requestion Tap of #{agent} by #{tapper} -> #{uuid}")
      return false unless agent.registration_server
      Log.notice("Tapping #{agent.full_name} at #{agent.registration_server}: #{uuid}")
      if (sock = FSR::CommandSocket.new(:server => agent.registration_server) rescue nil)
        if eavesdrop_extension = tapper.manager.eavesdrop_extension
          cmd = sock.originate(:target => eavesdrop_extension, :endpoint => "&eavesdrop(#{uuid})")
        elsif tapper.registration_server == agent.registration_server
          cmd = sock.originate(:target => "user/#{tapper.extension}", :endpoint => "&eavesdrop(#{uuid})")
        else
          cmd = sock.originate(:target => "sofia/internal/#{tapper.extension}@#{tapper.registration_server}", :endpoint => "&eavesdrop(#{uuid})")
        end
        Log.debug("Tap Command %p" % cmd.raw)
        cmd.run
      end
    end

    def got_agent_call_history(msg)
      # If we have tiny_cdr available, use it for call history,
      # otherwise use CallRecord
      Log.debug "Sending call history of #{msg['agent']}"
      Log.debug "tiny_cdr: #{TCC.options.tiny_cdr.db}"

      calls = if TCC.options.tiny_cdr.db
        extension = TCC::Account.extension(msg["agent"])
        TCC::TinyCdr::Call.history(extension).map{|row|
          row.values.merge(start_time: row.start_stamp.rfc2822)
        }
      else
        TCC::CallRecord.agent_history_a(msg["agent"])
      end

      reply(
        tiny_action: 'agent_call_history',
        cc_agent: msg['agent'],
        history: calls
      )
    end

    def got_agent_disposition_history(msg)
      calls = TCC::CallRecord.agent_history_a(msg["agent"])
      reply(
        tiny_action: 'agent_disposition_history',
        cc_agent: msg['agent'],
        history: calls
      )
    end

    def got_agent_status_history(msg)
      Log.debug "Sending status history of #{msg['agent']}"
      reply(
        tiny_action: 'agent_status_history',
        cc_agent: msg['agent'],
        history: TCC.options.mod_callcenter.db ? TCC::CallCenter::StatusLog.agent_history_a(msg["agent"]) : []
      )
    end

    def got_agent_state_history(msg)
      Log.debug "Sending state history of #{msg['agent']}"
      reply(
        tiny_action: 'agent_state_history',
        cc_agent: msg['agent'],
        history: TCC.options.mod_callcenter.db ? TCC::CallCenter::StateLog.agent_history_a(msg["agent"]) : []
      )
    end
  end
end
