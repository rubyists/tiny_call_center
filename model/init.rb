# Copyright (c) 2008-2009 The Rubyists, LLC (effortless systems) <rubyists@rubyists.com>
# Distributed under the terms of the MIT license.
# The full text can be found in the LICENSE file included with this software
#
require_relative '../lib/tiny_call_center'


# Here go your requires for models:

require 'sequel'
DB = Sequel.sqlite(File.dirname(__FILE__) + "/../db/call_center.db")
require_relative "./manager"

require_relative "./account"
