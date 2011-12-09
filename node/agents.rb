# Copyright (c) 2008-2009 The Rubyists, LLC (effortless systems) <rubyists@rubyists.com>
# Distributed under the terms of the MIT license.
# The full text can be found in the LICENSE file included with this software
#

module TinyCallCenter
  class Agents
    Innate.node "/agents", self
    layout :default
    helper :user, :flash, :fsr, :localize
    trait :user_model => TinyCallCenter::Account

    trait :agents => nil
    trait :queues => nil
    TYPES = ['callback', 'uuid-standby']
    STATUSES = ['Available', 'Logged Out', 'Available (On Demand)', 'On Break']

    before_all do
      redirect TCC::Accounts.r(:login) unless logged_in?
    end

    def index
      @title = "Agents"
      @agents = all_agents
    end

    def new
      @title = "Add Agent"
      @queues = ancestral_trait[:queues] ||
        fsr.call_center(:queue).list.run.map(&:name)
    end

    def all_agents
      (ancestral_trait[:agents] || fsr.call_center(:agent).list.run).
        sort_by{|agent| [agent.full_name, agent.extension] }
    end

    def list
      require "json"
      agents = all_agents.map do |a|
        a.to_hash
      end.to_json
      respond agents
    end

    def set(agent)
      flash[:errors] ||= []
      if (request.params["submit"] == "Delete") then
        delete(agent)
      else
        request.params.each do |k,v|
          cmd = fsr.call_center(:agent).set(agent, k.to_sym, v)
          unless cmd.run
            flash[:errors] << cmd.last_response
          end
        end
      end
      redirect_referer
    end

    def edit(agent)
      Innate::Log.debug 'fsr.call_center(:agent).list.run' => fsr.call_center(:agent).list.run
      @agent = fsr.call_center(:agent).list.run.find{|x| x.name == agent}
      @extension = Account.extension(@agent.name)
      @agent_name = Account.agent_name(@agent.name)
      @title = "Edit #{@agent_name}"
    end

    def add
      if agent = validate_agent(request.params)
        create_agent agent
        flash[:added] = "Added #{agent["name"]}"
      end
      redirect_referer
    end

    def update(agent)
      update_agent(request.params, agent)
      flash[:updated] = "Updated #{agent["name"]}"
      redirect :index
    end

    def delete(agent)
      delete_agent agent
      redirect_referer
    end

    private

    def find_contact(extension, timeout)
      "[leg_timeout=%d]sofia/internal/%s@%s" % [timeout, extension, Account.registration_server(extension)]
    end

    def create_agent(agent)
      flash[:errors] ||= []
      extension, name, timeout, type = agent.values_at("extension", "name", "timeout", "type")
      contact = agent["contact"] || find_contact(extension, timeout)
      cmd = fsr.call_center(:agent).add(name, type)
      if cmd.run
        ::Innate::Log.info "Added Agent #{name}: #{cmd.last_response}"
        cmd = fsr.call_center(:agent).set(name, :contact, contact)
        unless cmd.run
          flash[:errors] << "Could not set a contact string! #{cmd.last_response}"
        end
        ["max_no_answer", "wrap_up_time"].each do |att|
          next unless val = agent[att]
          cmd = fsr.call_center(:agent).set(name, att, val)
          unless cmd.run
            flash[:errors] << "Could not set #{att}: #{cmd.last_response}"
          end
        end
        initial_q= agent['initial_queue']
        cmd = fsr.call_center(:tier).add(name, initial_q, 1, 1)
        unless cmd.run
          flash[:errors] << "Could not set #{initial_q} for #{name}: #{cmd.last_response}"
        end
      else
        flash[:errors] << "Server returned an error: #{cmd.last_response}"
        false
      end
    end

    def update_agent(agent, agt)
      flash[:errors] ||= []
      extension, name, type = agent.values_at("extension", "name", "type")
      cmd = fsr.call_center(:agent).list
      unless cmd.run
        flash[:errors] << "Could not run  #{cmd.last_response}"
      else
      eagent = cmd.run.select {|x| x.name == agt }.first
      timeout = eagent ? eagent.contact.scan(/timeout=../)[0].to_s.gsub(/\D/,'') : 9
      contact = agent["contact"] || find_contact(extension, timeout)
      cmd = fsr.call_center(:agent).set(agt, :contact, contact)
        unless cmd.run
          flash[:errors] << "Could not set a contact string! #{cmd.last_response}"
        end
        ["max_no_answer", "wrap_up_time"].each do |att|
          next unless val = agent[att]
          cmd = fsr.call_center(:agent).set(agt, att, val)
          unless cmd.run
            flash[:errors] << "Could not set #{att}: #{cmd.last_response}"
          end
        end
      end
    end

    def delete_agent(agent)
      flash[:errors] ||= []
      cmd = fsr.call_center(:agent).del agent
      unless cmd.run
        flash[:errors] << "Could not delete the contact ! #{cmd.last_response}"
      end

    end

    def validate_agent(agent)
      errors ||= []
      name, extension = agent.values_at("name", "extension")
      errors << "extension can not be empty" unless extension.to_s.size > 0
      errors << "extension must be all digits" unless extension.to_s.match(/^\d+$/)
      errors << "name can not be empty" unless name.to_s.size > 0
      if errors.size == 0
        name = "%s-%s" % [extension, name.gsub(/\s+/,"_")]
        errors << "Duplicate Extension/Name not allowed" if all_agents.detect { |a| a.name == name }
      end
      if errors.size > 0
        flash[:errors] ||= []
        flash[:errors] += errors
        return false
      end
      agent.dup.merge({"name" => name}).reject { |k,v| v == "" }
    end
  end
end
