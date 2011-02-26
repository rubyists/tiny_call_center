# Copyright (c) 2008-2009 The Rubyists, LLC (effortless systems) <rubyists@rubyists.com>
# Distributed under the terms of the MIT license.
# The full text can be found in the LICENSE file included with this software
#
module TinyCallCenter
  class Tiers
    Innate.node "/tiers", self
    layout :default
    helper :user, :flash, :fsr
    trait :user_model => TinyCallCenter::Account

    trait :tiers => nil
    trait :agents => nil

    STATES = ['No Answer', 'Ready', 'Offering', 'Active Inbound', 'Standby']
    POSITIONS = '1'..'9'
    LEVELS = '1'..'9'

    before_all do
      redirect TCC::Accounts.r(:login) unless logged_in?
    end

    def index(queue = nil)
      if queue.nil?
        redirect r(:list)
      else
        @title = "Tiers"

        @queue = queue
        @tiers = fsr_tiers(queue) # each of these will be an agent/queue relationship
        @agents = fsr_agents(@tiers)
        agent_names = Set.new(@agents.map(&:name))
        @all_agents = fsr_all_agents.reject{|agent|
          agent_names.include?(agent.name)
        }.sort_by{|agent| agent.extension }
        @agent_table = Agents.render_view(:index, agents: @agents)
      end
    end

    def list
      fsr.call_center(:queue).list.run.
        sort_by{|agent| agent.name }.
        map{|agent|
          index(agent.name)
          render_view(:index) }.join
    end

    def mass_set(queue, agents = [], field_values = {})

    end

    def set_status
      agent, status = request[:agent, :status]
      respond('Client Failure', 412) unless request.post? && agent && status
      cmd = fsr.call_center(:agent).set(agent, :status, status)
      respond('OK', 200) if cmd.run
      respond('Server Failure', 500)
    end

    # this should be in a helper for the controllers, or I guess we could redirect to it?
    def set(agent, queue)
      flash[:errors] ||= []

      if request["submit"] == "Delete"
        delete_agent(agent, queue)
      else
        request.params.each do |key, value|
          case key
          when /submit|queue/
            next
          when 'status'
            cmd = fsr.call_center(:agent).set(agent, :status, value)
          else
            cmd = fsr.call_center(:tier).set(agent, queue, key.to_sym, value)
          end

          unless cmd.run
            flash[:errors] << "%s, %s, %s" % [cmd.last_response, key, value]
          end
        end
      end

      redirect_referer
    end

    # this should be in a model/module for the controllers
    def add_agent(queue, agent = nil, position = nil, level = nil)
      agent ||= request["agent"]
      position ||= request["position"] || 1
      level ||= request["level"] || 1
      flash[:errors] ||= []
      puts "agent: #{agent} queue#{queue} #{level} position #{position}"

      resp = fsr.call_center(:tier).add(agent, queue, level, position).run

      redirect_referer
    end

    # this should be in a module/model for the controllers
    def delete_agent(agent, queue)
      flash[:errors] ||= []
      resp = fsr.call_center(:tier).del(agent, queue).run
    end

    private

    # all of these should also be in a model/module, but they need access to 'fsr', which is already in another helper
    def fsr_tiers(queue)
      ancestral_trait[:tiers] || fsr.call_center(:tier).list(queue.to_sym).run
    end

    def fsr_all_agents
      ancestral_trait[:agents] || fsr.call_center(:agent).list.run
    end

    def fsr_agents(in_tiers)
      tier_agents = in_tiers.map(&:agent)
      fsr_all_agents.select{|agent| tier_agents.include?(agent.name) }
    end
  end
end
