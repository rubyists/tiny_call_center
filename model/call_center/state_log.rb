module TinyCallCenter
  module CallCenter
    class StateLog < Sequel::Model
      set_dataset FSCallCenter.db[:state_log]

      def self.agent_history_a(agent, from = Date.today, to = nil)
        agent_history(agent, from, to).map { |row|
          v = row.values

          case v[:new_state]
          when 'Waiting'
            v[:new_state] = 'Ready'
          when 'Idle'
            v[:new_state] = 'Wrap-up'
          end

          v
        }
      end

      def self.agent_history(agent, from = Date.today, to = nil)
        ds = filter{{:agent => agent} & (created_at > from)}
        ds = ds.filter{(created_at < to)} if to
        ds.select(:new_state, :created_at).order_by(:created_at.desc)
      end
    end
  end
end
