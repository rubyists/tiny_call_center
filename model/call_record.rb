require "date"
module TinyCallCenter
  class CallRecord < Sequel::Model
    set_dataset TinyCallCenter.db[:call_records]
    many_to_one :disposition

    def validate
      self[:created_at] = DateTime.now unless self[:created_at]
    end
  end
end
