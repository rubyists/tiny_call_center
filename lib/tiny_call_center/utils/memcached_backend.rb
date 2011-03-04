module TinyCallCenter
  module MemcachedBackend
    def initialize(*args, &block)
      require "memcached"
      @originate_cache = Memcached.new(TCC.options.memcached.servers, prefix_key: 'orig_')
      @answer_cache = Memcached.new(TCC.options.memcached.servers, prefix_key: 'answer_')
      super
    end

    def set_originate(uuid, msg)
      @originate_cache.set("#{uuid}", msg)
    end

    def get_originate(uuid)
      @originate_cache.get("#{uuid}") rescue nil
    end

    def set_answer(uuid, msg)
      @answer_cache.set("#{uuid}", msg)
    end

    def get_answer(uuid)
      @answer_cache.get("#{uuid}") rescue nil
    end
  end
end


