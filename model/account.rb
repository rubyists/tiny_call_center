require "nrs_ldap"
require_relative './manager'

module TinyCallCenter
  class Account < Sequel::Model
    set_dataset TinyCallCenter.db[:accounts]
    attr_reader :user

    def self.authenticate(creds)
      name, pass = creds.values_at("name", "pass")
      Account.find(username: name, password: pass)
    rescue => error
      Innate::Log.error error
      false
    end

    def self.registration_server(extension)
      user = from_extension(extension)
      user.registration_server
    rescue => error
      Innate::Log.error "Could not find user, defaulting reg server to 127.0.0.1"
      Innate::Log.error error
    end

    def self.username(agent)
      name agent.gsub('_', '')
    end

    def self.name(agent)
      agent.split('-',2).last
    end

    def self.extension(agent)
      agent.split('-',2).first
    end

    def self.from_call_center_name(agent)
      find username: username(agent)
    end

    def self.from_full_name(name)
      find username: name.gsub("_", '').gsub(/\s/,'')
    end

    def self.from_extension(ext)
      find extension: ext
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
        TinyCallCenter::Manager.find(username: username ||
        TinyCallCenter::Manager.find(username: "#{first_name.downcase.capitalize}#{last_name.downcase.capitalize}")
      )
    end

    def can_view?(extension)
      return false unless manager
      manager.authorized_to_listen?(extension, extension)
    end

    def manager?
      manager
    end
  end
end
