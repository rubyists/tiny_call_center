module TinyCallCenter
  module MemcachedBackend
    def initialize(*args, &block)
      begin
      require "memcache"
      rescue LoadError => ex
        p ex
      end

      @originate_cache = MemCache.new(TCC.options.memcached.servers, prefix_key: 'orig_')
      @answer_cache = MemCache.new(TCC.options.memcached.servers, prefix_key: 'answer_')

      super
    rescue => ex
      puts ex, ex.backtrace
      Log.error(ex)
      abort "Error in memcached: #{ex}"
    end

    def set_originate(uuid, msg)
      @originate_cache.set("#{uuid}", msg)
    end

    def get_originate(uuid)
      @originate_cache.get("#{uuid}", nil) rescue nil
    end

    def set_answer(uuid, msg)
      @answer_cache.set("#{uuid}", msg)
    end

    def get_answer(uuid)
      @answer_cache.get("#{uuid}", nil) rescue nil
    end
  end
end
