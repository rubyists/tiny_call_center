# Copyright (c) 2008-2009 The Rubyists, LLC (effortless systems) <rubyists@rubyists.com>
# Distributed under the terms of the MIT license.
# The full text can be found in the LICENSE file included with this software

require_relative '../../helper'

require "fsr/model/tier"
require "fsr/model/agent"

Innate.options.roots = [File.expand_path('../../../../', __FILE__)]

describe 'TinyCallCenter Agents' do
  behaves_like :rack_test, :make_account

  it "Shows an empty Tier" do
    aheaders = ["name", "system", "uuid", "type", "contact", "status", "state", "max_no_answer","wrap_up_time", "reject_delay_time", "busy_delay_time","last_bridge_start", "last_bridge_end", "last_offered_call", "last_status_change", "no_answer_count", "calls_answered", "talk_time", "ready_time"]

    adata = ["1011-John_Lennon", "single_box", nil, "callback", "[leg_timeout=10]sofia/internal/1011@192.168.6.240",
            "Logged Out", "Waiting", "10", "10", "10", "10", "1288650045", "1288650221", "1288650038",
            "1288640724", "0", "4", "320", "0"]
    adata2 = ["1012-Paul_McCartney", "single_box", nil, "callback", "[leg_timeout=11]sofia/internal/1012@192.168.6.240",
            "Logged Out", "Waiting", "10", "10", "10", "10", "1288650045", "1288650221", "1288650038",
            "1288640724", "0", "4", "320", "0"]
    agent = FSR::Model::Agent.new(aheaders, *adata)
    agent2 = FSR::Model::Agent.new(aheaders, *adata2)

    TinyCallCenter::Tiers.trait tiers: []
    TinyCallCenter::Tiers.trait agents: [agent, agent2]

    res = get('/tiers/helpdesk@default')
    doc = Nokogiri::HTML(res.body)
    doc.should.not.be.nil
  end

  it "Shows A Tier Listing" do
    # TODO Load an innate node, set a trait of FSR::Model::Tier instances
    # and then test the view output
    # Example tier item instance:
    headers = ["queue", "agent", "state", "level", "position"]
    data = ["helpdesk@default", "1011-John_Lennon", "No Answer", "1", "1"]
    data2 = ["helpdesk@default", "1012-Paul_McCartney", "Ready", "2", "1"]
    #Example agent instance
    aheaders = ["name", "system", "uuid", "type", "contact", "status", "state", "max_no_answer","wrap_up_time", "reject_delay_time", "busy_delay_time","last_bridge_start", "last_bridge_end", "last_offered_call", "last_status_change", "no_answer_count", "calls_answered", "talk_time", "ready_time"]

    adata = ["1011-John_Lennon", "single_box", nil, "callback", "[leg_timeout=10]sofia/internal/1011@192.168.6.240",
            "Logged Out", "Waiting", "10", "10", "10", "10", "1288650045", "1288650221", "1288650038",
            "1288640724", "0", "4", "320", "0"]
    adata2 = ["1012-Paul_McCartney", "single_box", nil, "callback", "[leg_timeout=11]sofia/internal/1012@192.168.6.240",
            "Logged Out", "Waiting", "10", "10", "10", "10", "1288650045", "1288650221", "1288650038",
            "1288640724", "0", "4", "320", "0"]
    agent  = FSR::Model::Agent.new(aheaders, *adata)
    agent2 = FSR::Model::Agent.new(aheaders, *adata2)

    tier1 = FSR::Model::Tier.new(headers, *data)
    tier2 = FSR::Model::Tier.new(headers, *data2)

    TinyCallCenter::Tiers.trait tiers: [tier1, tier2], agents: [agent, agent2]

    res = get('/tiers/helpdesk@default')
    doc = Nokogiri::HTML(res.body)

    doc.css('form.tier-control').first[:action].should == '/tiers/set/1011-John_Lennon/helpdesk@default'
    doc.css('form.tier-control .name').first.text.should == '1011-John_Lennon'
    doc.xpath('//option[@selected]/@value').map { |n| n.text}.should == ["No Answer", "Logged Out", "1", "1", "Ready", "Logged Out", "2", "1"]
  end
end
