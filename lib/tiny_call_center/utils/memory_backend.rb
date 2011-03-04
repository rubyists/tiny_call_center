module TinyCallCenter
  module MemoryBackend
    def initialize(*args, &block)
      @channel_answers, @channel_originates = {}, {}
      super
    end

    def set_originate(uuid, msg)
      @channel_originates[uuid] = msg
    end

    def get_originate(uuid)
      @channel_originates[uuid]
    end

    def set_answer(uuid, msg)
      @channel_answers[uuid] = msg
    end

    def get_answer(uuid)
      @channel_answers[uuid]
    end
  end
end




