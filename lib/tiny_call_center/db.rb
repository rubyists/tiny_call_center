require 'sequel'
require_relative "../../options"
module TinyCallCenter
  unless defined?(@@db)
    @@db = nil
  end

  def self.db
    @@db ||= Sequel.connect(TinyCallCenter.options.db)
  end

  def self.db=(other)
    @@db = other
  end
end
