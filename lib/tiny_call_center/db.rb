require 'sequel'
require_relative "../../options"

module TinyCallCenter
  @db ||= nil

  def self.db
    @db ||= Sequel.connect(TinyCallCenter.options.db)
  end

  def self.db=(other)
    @db = Sequel.connect(other)
  end
end
