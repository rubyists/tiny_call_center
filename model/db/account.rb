require_relative '../manager'
require "digest/sha1"

module TinyCallCenter
  class Account < Sequel::Model
    set_dataset TinyCallCenter.db[:accounts]
    attr_reader :user

    def self.authenticate(creds)
      name, pass = creds.values_at("name", "pass")
      Account.find(username: name, password: TinyCallCenter::Account.digestify(pass))
    rescue => error
      Log.error error
      Log.error error.backtrace.join("\n\t")
      false
    end

    def self.digestify(pass)
      Digest::SHA1.hexdigest(pass.to_s)
    end

    def password=(other)
      self[:password] = ::TinyCallCenter::Account.digestify(other)
    end

    def self.registration_server(extension)
      user = from_extension(extension)
      if user
        user.registration_server
      else
        Log.warn "User not found for #{extension}, using #{proxy = TCC.options.internal_proxy}"
        proxy
      end
    rescue => error
      Log.error "Unknown problem, defaulting reg server to 127.0.0.1"
      Log.error error
      Log.error error.backtrace.join("\n\t")
      '127.0.0.1'
    end

    def self.username(agent)
      full_name agent.tr(' ', '')
    end

    def self.agent_name(agent)
      agent.split('-',2).last
    end

    def self.full_name(agent)
      agent.split('-', 2).last.tr("_", " ")
    end

    def self.extension(agent)
      agent.split('-',2).first
    end

    def self.from_call_center_name(agent)
      from_extension extension(agent)
    end

    def self.from_full_name(name)
      find username: full_name(name).gsub("_", '').gsub(/\s/,'')
    end

    def self.from_extension(ext)
      find extension: ext
    end

    def self.all_usernames
      map{|account| account.username }
    end

    def exists?
      @new_record ? false : true
    end

    def user_raw
      @user_raw ||= dataset
    end

    def find_user
      user_raw
    end

    def full_name
      "%s %s" % [first_name, last_name]
    end

    def agent
      "%s-%s_%s" % [extension, first_name, last_name]
    end

    def manager
      @_manager ||= (
        TinyCallCenter::Manager.find(username: username) ||
        TinyCallCenter::Manager.find(username: "#{first_name.downcase.capitalize}#{last_name.downcase.capitalize}")
      )
    end

    def can_view?(extension)
      return false unless manager
      manager.authorized_to_listen?(extension, extension)
    end

    def manager?
      !!manager
    end

    def status=(new_status)
      Log.debug "set status of #{agent} to #{new_status}"
      FSListener.execute registration_server do |listener|
        listener.callcenter!{|cc| cc.set(agent, :status, new_status) }
      end
    end

    # we cannot give status to the web interface this way
    def status
    end

    def state=(new_state)
      Log.debug "set state of #{agent} to #{new_state}"
      FSListener.execute registration_server do |listener|
        listener.callcenter!{|cc| cc.set(agent, :state, new_state) }
      end
    end

    # TODO: might not work
    def get_queued
      sock.originate(
        target: "user/#{extension}",
        target_options: {tcc_agent: agent},
        endpoint: "&transfer(19999)"
      )
    end
  end
end
