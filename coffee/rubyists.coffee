p = -> window.console?.debug?(arguments ...)

window.Rubyists ||= {}

class Socket
  constructor: (@options) ->
    @webSocket = if "MozWebSocket" of window then MozWebSocket else WebSocket
    @connected = false
    @frame = 0
    @callbacks = {}
    @connect()

  connect: () ->
    @reconnector = setInterval((=> @reconnect()), 1000)

  reconnect: () ->
    return if @connected

    @socket = new @webSocket(@options.server)
    @socket.onmessage = (messageEvent) =>
      parsed = JSON.parse(messageEvent.data)
      p 'parsed', parsed
      if callback = @callbacks[parsed.frame]
        delete @callbacks[parsed.frame]
        if body = parsed.ok
          callback(body, true)
          @onmessage(body)
        else if error = parsed.error
          callback(error, false)
          @onmessage(error)
    @socket.onerror = => @onerror(arguments ...)

    @socket.onopen = =>
      @connected = true
      @onopen(arguments ...)

    @socket.onclose = =>
      @connected = false
      @onclose(arguments ...)

  onopen: ->
    p 'open', this

  onmessage: (body) ->
    p 'message', body

  onclose: ->
    p 'close', this

  onerror: (error) ->
    p 'error', error

  say: (message, callback) ->
    @frame += 1
    packet = {
      frame: @frame,
      body: message,
    }
    @callbacks[@frame] = callback
    p packet: packet
    @socket.send(JSON.stringify(packet))

  request: (given) ->
    @say given.data, (response, status) ->
      if status == true
        given.success?(response)
      else
        given.error?(response)

window.Rubyists.Socket = Socket

BackboneWebSocketSync = (method, model, options) ->
  data = {
    method: method,
    url: model.url,
    id: model.id,
    attributes: model,
  }

  switch method
    when 'update'
      p 'changed', model.changedAttributes()
      data.attributes = model.changedAttributes()

  Rubyists.syncSocket.request(
    data: data,
    success: options.success,
    error: options.error
  )

window.Rubyists.BackboneWebSocketSync = BackboneWebSocketSync
