module TinyCallCenter
  module RedisBackend
    def initialize(*args, &block)
      require "redis"

      options = TCC.options.redis
      host, port = options.server.split(':')

      @originate_cache = Redis.new(host: host, port: port)
      @answer_cache = Redis.new(host: host, port: port)
      @ttl = options.ttl

      super
    rescue => ex
      puts ex, ex.backtrace
      Log.error(ex)
      abort "Error in redis init: #{ex}"
    end

    def set_originate(uuid, msg)
      key = "originate_#{uuid}"
      @originate_cache.setex(key, @ttl, msg)
      msg
    end

    def get_originate(uuid)
      @originate_cache["originate_#{uuid}"]
    end

    def set_answer(uuid, msg)
      key = "answer_#{uuid}"
      @answer_cache.setex(key, @ttl, msg)
      msg
    end

    def get_answer(uuid)
      @answer_cache["answer_#{uuid}"]
    end
  end
end
