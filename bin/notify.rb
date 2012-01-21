#!/usr/bin/env ruby
require "em-postgres"
channels = %w{channel_insert channel_update channel_delete}
EventMachine.run {
  conn = EventMachine::Postgres.new(:database => 'freeswitch', :port => 5435)
  channels.each do |channel|
    q = conn.execute("LISTEN #{channel};") { |res| p channel + " Subscribed" }
    q.errback{|r| warn "Error: %s" % r }
  end

  EventMachine.add_timer(1) do
    EventMachine.add_periodic_timer(0) {
      p 'Waiting for notifications'
      conn.wait_for_notify(*[]) { |chan, pid, payload| p ['Notify Received', chan, pid, payload]; $stdout.flush }
    }
  end
}
