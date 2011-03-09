module TinyCallCenter
  module CallCenter
    class Tier < Sequel::Model
      set_dataset FSCallCenter.db[:tiers]

      def self.extension_primary_queue(extension)
        if account = TCC::Account.from_extension(extension)
          agent_primary_queue(account.agent)
        else
          false
        end
      end

      def self.agent_primary_queue(agent)
        sub = filter(:agent => agent).select(:queue)
        ds = filter(:queue => sub).select(:queue, :count.sql_function("*")).group(:queue).order(:count.desc)
        queue = ds.first
      end
    end
  end
end
