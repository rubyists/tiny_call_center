# Copyright (c) 2008-2009 The Rubyists, LLC (effortless systems) <rubyists@rubyists.com>
# Distributed under the terms of the MIT license.
# The full text can be found in the LICENSE file included with this software

require_relative '../../helper'
require "fsr/model/queue"

# Innate.options.roots = ['./']
# Innate.options.started = true
# Innate.setup_dependencies

describe 'TinyCallCenter Queue' do
  behaves_like :rack_test, :make_account

  it "Shows A list of Queues" do
    # TODO Load an innate node, set @queues to an array of  FSR::Model::Queue instances
    # and then test the view output
    # Example queue instance:
    headers = ["name", "strategy", "moh_sound", "time_base_score", "tier_rules_apply",
                  "tier_rule_wait_second", "tier_rule_wait_multiply_level",
                  "tier_rule_no_agent_no_wait", "discard_abandoned_after",
                  "abandoned_resume_allowed", "max_wait_time", "max_wait_time_with_no_agent",
                  "record_template"]
    data = ["helpdesk@default", "longest-idle-agent", "local_stream://moh", "system",
               "false", "30", "true", "true", "60", "false", "0", "0",
               "/home/freeswitch/recordings/${strftime(%Y-%m-%d-%H-%M-%S)}.${destination_number}.${caller_id_number}.${uuid}.wav"]
    queue = FSR::Model::Queue.new(headers, *data)

    action = TinyCallCenter::Queues.resolve('/')
    action.variables[:queues] = [queue]

    raw = action.render
    doc = Nokogiri::HTML(raw)
    (doc/:td).map(&:text).should == ["Name", "Strategy", "helpdesk@default", "longest-idle-agent"]
  end
end
