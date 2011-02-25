module TinyCallCenter
  class StatusLog < Sequel::Model
    set_dataset FSCallCenter.db[:status_log]

    def self.agent_history(agent, from = Date.today, to = nil)
      ds = filter{{:agent => agent} & (created_at > from)}
      ds = ds.filter{(created_at < to)} if to
      ds.select(:new_status, :created_at).order_by(:created_at.desc)
    end

    def self.agent_history_a(agent, from = Date.today, to = nil)
      agent_history(agent, from, to).map(&:values)
    end

  end
end
