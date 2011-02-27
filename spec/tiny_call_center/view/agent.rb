# Copyright (c) 2008-2009 The Rubyists, LLC (effortless systems) <rubyists@rubyists.com>
# Distributed under the terms of the MIT license.
# The full text can be found in the LICENSE file included with this software
#
require File.expand_path('../../../spec_helper', __FILE__)
require File.expand_path('../../../fsr_helper', __FILE__)
require "fsr/model/agent"
require File.expand_path('../../../../app', __FILE__)
require 'innate/spec/bacon'
require 'nokogiri'

Innate.options.roots = [File.expand_path('../../../../', __FILE__)]

describe 'FsrCallcenter Agents' do
  behaves_like :rack_test

  it "Shows A list of Agents" do
    # TODO Load an innate node, set @queues to an array of  FSR::Model::Agent instances
    # and then test the view output
    # Example agent instance:
    headers = ["name", "system", "uuid", "type", "contact", "status", "state", "max_no_answer",
               "wrap_up_time", "reject_delay_time", "busy_delay_time", "last_bridge_start",
               "last_bridge_end", "last_offered_call", "last_status_change", "no_answer_count",
               "calls_answered", "talk_time", "ready_time"]
    data = ["1011-John_Lennon", "single_box", nil, "callback", "[leg_timeout=10]sofia/internal/1011@192.168.6.240",
            "Available", "Waiting", "10", "10", "10", "10", "1288650045", "1288650221", "1288650038",
            "1288640724", "0", "4", "320", "0"]
    data2 = ["1012-Paul_McCartney", "single_box", nil, "callback", "[leg_timeout=10]sofia/internal/1012@192.168.6.240",
            "Logged Out", "Waiting", "10", "10", "10", "10", "1288650045", "1288650221", "1288650038",
            "1288640724", "0", "4", "320", "0"]
    agent = FSR::Model::Agent.new(headers, *data)
    agent2 = FSR::Model::Agent.new(headers, *data2)

    TinyCallCenter::Agents.trait agents: [agent]

    res = get('/agents/')
    doc = Nokogiri::HTML(res.body)
    doc.xpath('//form[action="/agents/set/1011-John_Lennon"]').should.not == nil
    doc.css('form .name').text.should == 'John Lennon'
    doc.xpath('//option[@selected]/@value').text.should == 'Available'
  end
end
