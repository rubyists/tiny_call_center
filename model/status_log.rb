module TinyCallCenter
  class StatusLog < Sequel::Model
    set_dataset FSCallCenter.db[:status_log]
  end
end
