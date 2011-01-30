require 'innate'

module TinyCallCenter
  include Innate::Optioned

  options.dsl do
    sub :listener do
      o "WebSocket server URI", :server,
        (ENV["TinyCallCenter_WebSocketURI"] ? URI(ENV["TinyCallCenter_WebSocketURI"]) : URI('ws://127.0.0.1:8080/websocket'))
    end

    o "FreeSWITCH Command Server", :command_server,
      ENV["TinyCallCenter_SERVER"] || '127.0.0.1'

    o "FreeSWITCH Command Server", :fs_port,
      ENV["TinyCallCenter_FsPort"] || 8021

    o "FreeSWITCH Command Server", :fs_auth,
      ENV["TinyCallCenter_FsAuth"] || "ClueCon"

    o "FreeSWITCH Registration Servers For Agents", :registration_servers,
      (ENV["TinyCallCenter_Monitors"] ? ENV["TinyCallCenter_Monitors"].split(":") : ['127.0.0.1'])

    o "Agents Off-Hook instead of On-Hook", :off_hook,
      ENV["TinyCallCenter_OffHook"] || false
  end
end
