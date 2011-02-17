require "date"
module TinyCallCenter
  class CallRecord < Sequel::Model
    set_dataset TinyCallCenter.db[:call_records]
    many_to_one :disposition

    def self.last(username)
      CallRecord.filter(agent: username).order(:created_at.desc).limit(1).first
    end

    def validate
      self[:created_at] = DateTime.now unless self[:created_at]
    end
  end
end
