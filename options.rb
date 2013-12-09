require 'innate'
require 'pgpass'

module TinyCallCenter
  include Innate::Optioned

  pgpass = lambda{|options|
    Log.info "Connecting to #{options}"
    begin
      if found = Pgpass.match(options)
        found.to_url
      else
        raise "No entry in .pgpass for %p" % [options]
      end
    rescue
      raise "No entry in .pgpass for %p" % [options]
    end
  }

  options.dsl do
    o "SIP External Proxy Server Format String (To make calls to PSTN)", :proxy_server_fmt,
      ENV["TCC_ProxyServerFormatString"] || 'sofia/gateway/default/%s'

    o "SIP Internal Proxy Server IP (available via sofia/internal/)", :internal_proxy,
      ENV["TCC_InternalProxy"] || '127.0.0.1'

    sub :listener do
      o "WebSocket server URI for listeners", :server,
        URI(ENV["TCC_WebSocketListenerURI"] || 'ws://127.0.0.1:8081/websocket')
    end

    sub :live2 do
      o "WebSocket server for live2", :server,
        URI(ENV['TCC_WebSocketListenerURI'] || 'ws://127.0.0.1:43444/websocket')
    end

    sub :ribbon do
      o "WebSocket server URI for agents", :server,
        URI(ENV["TCC_WebSocketAgentURI"] || 'ws://127.0.0.1:8080/websocket')
    end

    sub :ribbon2 do
      o "WebSocket server URI for agents", :server,
        URI(ENV["TCC_WebSocketAgentURI"] || 'ws://127.0.0.1:43443')
    end

    sub :mod_callcenter do
      o 'Mod_callcenter postgres database uri (postgres://user:pass@host/callcenter)', :db,
        ENV["TCC_ModCallcenterDB"] || pgpass.(database: 'callcenter')
    end

    sub :memcached do
      o 'Memcached servers to use for answer/originate hashes', :servers,
        ENV["TCC_MemcachedServers"].to_s.split(',')
    end

    sub :beanstalk do
      o 'Beanstalk servers to use for queue (host:port)', :servers,
        ENV["TCC_BeanstalkServers"] ? ENV["TCC_BeanstalkServers"].to_s.split(',') : ["localhost:11300"]

      o 'Beanstalk tubes to listen for dequeueing', :listen_tubes,
        ENV["TCC_BeanstalkListenTubes"] ? ENV["TCC_BeanstalkListenTubes"].to_s.split(":") : ["tcc_pg"]

      o 'Beanstalk tube to send for enqueueing', :send_tube,
        ENV["TCC_BeanstalkSendTube"] || "tcc_pg"
    end

    sub :redis do
      o 'Redis server to use for answer/originate hashes', :server,
        ENV['TCC_RedisServer'] || '127.0.0.1:6379'

      o 'TTL for cached entries in Redis', :ttl,
        (ENV['TCC_RedisTTL'] || (12 * 60 * 60)).to_i
    end

    sub :fxc do
      o 'FXC Root Directory', :root,
        ENV["FXC_Root"]
    end

    sub :tiny_cdr do
      o 'TinyCdr postgres database uri', :db,
        ENV["TCC_TinyCdrDB"] || pgpass.(database: 'tiny_cdr')
      o 'TinyCdr couch db uri', :couch_uri,
        ENV["TCC_TinyCdrCouchURI"]
    end

    o "FreeSWITCH Command Server", :command_server,
      ENV["TCC_Server"] || '127.0.0.1'

    o "FreeSWITCH Command Server Port", :fs_port,
      ENV["TCC_FsPort"] || 8021

    o "FreeSWITCH Command Server Authentication", :fs_auth,
      ENV["TCC_FsAuth"] || "ClueCon"

    o "FreeSWITCH Registration Servers For Agents", :registration_servers,
      (ENV["TCC_Monitors"] ? ENV["TCC_Monitors"].split(":") : ['127.0.0.1'])

    o "Agents Off-Hook instead of On-Hook", :off_hook,
      ENV["TCC_OffHook"] || false

    o "Sequel Database URI (adapter://user:pass@host/database)", :db,
      ENV["TCC_DB"] || pgpass.(database: 'tcc')

    o "Accounts Backend", :backend, (ENV["TCC_Backend"] || 'db')

    o "Log Level (DEBUG, DEVEL, INFO, NOTICE, ERROR, CRIT)", :log_level,
      ENV["TCC_LogLevel"] || "INFO"

    o "QueueRouter Listener Port", :qr_port,
      ENV["TCC_QrPort"] || 8884

    o "QueueRouter Listener Address", :qr_addr,
      ENV["TCC_QrAddress"] || "127.0.0.1"

    o "Mode for spec", :mode,
      ENV['TCC_Mode'] || 'live'
  end
end
