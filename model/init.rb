# Copyright (c) 2008-2009 The Rubyists, LLC (effortless systems) <rubyists@rubyists.com>
# Distributed under the terms of the MIT license.
# The full text can be found in the LICENSE file included with this software
#
require_relative '../lib/tiny_call_center'
require_relative '../lib/tiny_call_center/db'

DB = TinyCallCenter.db unless Object.const_defined?("DB")

# Here go your requires for models:


require_relative "./manager"
require_relative "./account"
require_relative "./disposition"
