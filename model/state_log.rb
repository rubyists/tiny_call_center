module TinyCallCenter
  class StateLog < Sequel::Model
    set_dataset FSCallCenter.db[:state_log]
  end
end
