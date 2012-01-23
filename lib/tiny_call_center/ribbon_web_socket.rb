require 'json'
require 'em-websocket'
# plugin must be loaded first!
require 'sequel'
Sequel::Model.plugin :json_serializer
require TCC::MODEL_ROOT/:init

module TCC
  class RibbonWebSocket < EM::WebSocket::Connection
    def self.start(options, &block)
      EM.epoll?
      @fsr_socket = options.delete :fsr_socket

      EM.run do
        EM.start_server(options[:host], options[:port], self, options, &block)
      end
    end

    def trigger_on_message(message)
      Log.debug "Message: %p" % {message: message}
      raw = JSON.parse(message)
      frame, body = raw.values_at('frame', 'body')
      url, method, id, attr =
        body.values_at('url', 'method', 'id', 'attributes')

      bbm = "backbone_#{method}"
      if url == 'Agent'
        say frame: frame, ok: __send__(bbm, id, attr)
      else
        raise 'Unknown url %p in %p' % [url, raw]
      end

    rescue => ex
      Log.error(ex)
      say frame: frame, error: ex.to_s
    end

    def say(obj)
      Log.debug say: obj
      send(obj.to_json)
    end

    EXPOSE = [
      :id, :first_name, :last_name, :registration_server,
      :username, :extension
    ]

    def backbone_read(id, attributes)
      Log.debug read: {id: id, attributes: attributes}

      if id
        account = Account[id: id]
      else
        ext = attributes['extension']
        account = Account[extension: ext]
        agent_connected(account)
      end

      raise 'no account found' unless account
      JSON.parse(account.to_json(only: EXPOSE))
    end

    def agent_connected(account)
      FSR.load_all_commands
      fsr = FSR::CommandSocket.new(server: TCC.options.command_server)
      cmd = fsr.call_center(:agent).set(account.agent, :status, 'Available')
      Log.debug cmd.raw
      Log.debug cmd.run
    end

    def channel_type(channel)
      channel.to_s.split("_",2)
    end

    def backbone_create(*args)
      channel, json = args
      channel, message = channel_type channel
      Log.debug "#{message.capitalize} #{channel}" => json
    end

    def backbone_update(*args)
      channel, json = args
      channel, message = channel_type channel
      Log.debug "#{message.capitalize} #{channel}" => json
    end

    def backbone_delete(*args)
      channel, json = args
      channel, message = channel_type channel
      Log.debug "#{message.capitalize} #{channel}" => json
    end
  end
end


