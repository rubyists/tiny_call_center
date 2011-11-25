# Copyright (c) 2008-2009 The Rubyists, LLC (effortless systems) <rubyists@rubyists.com>
# Distributed under the terms of the MIT license.
# The full text can be found in the LICENSE file included with this software

require_relative '../helper'

describe 'TinyCallCenter' do
  it "loads FSR" do
    FSR.should.respond_to?(:load_all_commands)
    FSR.should.respond_to?(:load_all_applications)
  end
end
