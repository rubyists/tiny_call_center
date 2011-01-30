# Copyright (c) 2008-2009 The Rubyists, LLC (effortless systems) <rubyists@rubyists.com>
# Distributed under the terms of the MIT license.
# The full text can be found in the LICENSE file included with this software
#
require File.expand_path('../../spec_helper', __FILE__)

describe 'TinyCallCenter' do
  it "loads FSR" do
    TinyCallCenter.load_fsr.should.be.true
  end
end
