require "date"
module TinyCallCenter
  class CallRecord < Sequel::Model
    set_dataset TinyCallCenter.db[:call_records]
    many_to_one :disposition

    def self.last(username)
      CallRecord.filter(agent: username).order(:created_at.desc).limit(1).first
    end

    def self.agent_history(agent, from = Date.today, to = nil)
      ds = filter{{:agent => agent} & (created_at > from)}
      ds = filter{(created_at < to)} if to
      ds.order_by(:created_at.desc)
    end

    def self.agent_history_a(agent, from = Date.today, to = nil)
      agent_history(agent, from, to).map(&:values)
    end

    def validate
      self[:created_at] = DateTime.now unless self[:created_at]
    end
  end
end
