module TinyCallCenter
  class Disposition < Sequel::Model
    set_dataset TinyCallCenter.db[:dispositions]
    one_to_many :call_records
    def to_s
      "code: #{code}, key: #{key}, desc: #{description}"
    end
  end
end
