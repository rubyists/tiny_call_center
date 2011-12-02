# Copyright (c) 2008-2009 The Rubyists, LLC (effortless systems) <rubyists@rubyists.com>
# Distributed under the terms of the MIT license.
# The full text can be found in the LICENSE file included with this software
#
require_relative '../lib/tiny_call_center'
require_relative '../lib/tiny_call_center/db'

DB ||= TinyCallCenter.db unless Object.const_defined?("DB")

module TinyCallCenter
  module FSCallCenter
    @db ||= nil

    def self.db
      @db ||= Sequel.connect(TinyCallCenter.options.mod_callcenter.db)
    end

    def self.db=(other)
      @db = other
    end
  end

  module TinyCdr
    @db ||= nil

    def self.db
      @db ||= Sequel.connect(TinyCallCenter.options.tiny_cdr.db)
    end

    def self.db=(other)
      @db = other
    end
  end

  module FXC
    @db ||= nil

    def self.db
      @db ||= Sequel.connect(TinyCallCenter.options.fxc.db)
    end

    def self.db=(other)
      @db = other
    end
  end
end

# Here go your requires for models:

require_relative "manager"
require_relative "#{TinyCallCenter.options.backend}/account"
require_relative "disposition"
require_relative "call_record"

if TinyCallCenter.options.mod_callcenter.db
  require_relative 'call_center/status_log'
  require_relative 'call_center/state_log'
  require_relative 'call_center/tier'
end

if TinyCallCenter.options.tiny_cdr.db
  require_relative 'tiny_cdr_call'
end

if TinyCallCenter.options.fxc.db
  require_relative "fxc_init"
end
