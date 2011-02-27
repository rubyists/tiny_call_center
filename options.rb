require 'innate'

module TinyCallCenter
  include Innate::Optioned

  options.dsl do
    o "SIP External Proxy Server Format String (To make calls to PSTN)", :proxy_server_fmt,
      ENV["TCC_ProxyServerFormatString"] || 'sofia/gateway/default/%s'

    o "SIP Internal Proxy Server IP (available via sofia/internal/)", :internal_proxy,
      ENV["TCC_InternalProxy"] || '127.0.0.1'

    sub :listener do
      o "WebSocket server URI for listeners", :server,
        URI(ENV["TCC_WebSocketListenerURI"] || 'ws://127.0.0.1:8081/websocket')
    end

    sub :ribbon do
      o "WebSocket server URI for agents", :server,
        URI(ENV["TCC_WebSocketAgentURI"] || 'ws://127.0.0.1:8080/websocket')
    end

    sub :mod_callcenter do
      o 'Mod_callcenter postgres database uri', :db,
        ENV["TCC_ModCallcenterDB"] # example: 'postgres://callcenter:PASSWORD@localhost/callcenter'
    end

    sub :tiny_cdr do
      o 'TinyCdr postgres database uri', :db,
        ENV["TCC_TinyCdrDB"]
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
      ENV["TCC_DB"] || "sqlite://%s" % File.expand_path("../db/call_center.db", __FILE__)

    o "Accounts Backend", :backend, ENV["TCC_Backend"]

    o "Log Level (DEBUG, DEVEL, INFO, NOTICE, ERROR, CRIT)", :log_level,
      ENV["TCC_LogLevel"] || "INFO"
  end
end
