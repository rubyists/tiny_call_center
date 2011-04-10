p = ->
  window.console?.debug?(arguments)

store = {
}

class Socket
  constructor: (@controller) ->
    @connect()

  connect: () ->
    @ws = new WebSocket(store.server)
    @reconnector = setInterval =>
      unless @connected
        @ws = new WebSocket(store.server)
        @prepareWs()
    , 1000

  prepareWs: ->
    @ws.onopen = =>
      @say(method: 'subscribe', agent: store.agent)
      @connected = true

    @ws.onmessage = (message) =>
      data = JSON.parse(message.data)
      @controller.dispatch(data)

    @ws.onclose = =>
      p "Closing WebSocket"
      @connected = false

    @ws.onerror = (error) =>
      p "WebSocket Error:", error

  say: (obj) ->
    @ws.send(JSON.stringify(obj))

class Controller
  dispatch: (msg) ->
    # it'll just subscribe to originate, answer, hangup, maybe a couple others.
    p msg

$ ->
  store.server = $('#server').text()
  store.server = "ws://" + location.hostname + ":8081/websocket" if store.server == ''
  store.agent = $('#agent_name').text()

  store.protoLog = $('#proto-log').detach()

  store.ws = new Socket(new Controller())
  window.tcc_store = store # makes debugging sooo much easier :)
