p = ->
  window.console?.debug?(arguments)

store = {
  pause: false,
}

class Socket
  constructor: (@controller) ->
    @connect()

  connect: () ->
    webSocket = if "MozWebSocket" of window then MozWebSocket else WebSocket
    @ws = new webSocket(store.server)
    @reconnector = setInterval =>
      unless @connected
        @ws = new webSocket(store.server)
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
    return if store.pause
    # it'll just subscribe to originate, answer, hangup, maybe a couple others.
    p msg

    if msg.tiny_action
      display = msg

      switch msg.tiny_action
        when "status_change"
          display = {
            Action: "Status change"
            Agent: msg.cc_agent,
            Status: msg.cc_agent_status,
          }
        when "state_change"
          display = {
            Action: "State change",
            Agent: msg.cc_agent,
            State: msg.cc_agent_state,
          }
        when 'call_start'
          display = {
            Action: "Call",
            Agent: msg.cc_agent,
          }

          ext = msg.cc_agent.split('-')[0]
          extMatch = /(?:^|\/)(?:sip:)?(\d+)[@-]/
          [left, right] = [msg.left, msg.right]
          leftMatch = left.channel?.match?(extMatch)?[1]
          rightMatch = right.channel?.match?(extMatch)?[1]

          if ext == leftMatch
            display.Detail = left.destination
          else if ext == rightMatch
            display.Detail = right.destination
          else if right.destination == rightMatch
            display.Detail = right.destination
          else if left.destination == leftMatch
            display.Detail = left.destination
          else if left.cid_number == leftMatch
            display.Detail = left.destination
          else if right.cid_number == rightMatch
            display.Detail = right.destination
        when 'channel_hangup'
          display = {
            Action: "Hangup",
            Agent: msg.cc_agent,
          }

          ext = msg.cc_agent.split('-')[0]

          if ext == msg.caller_callee_id_number
            display.Detail = msg.caller_caller_id_number
          else if ext == msg.caller_caller_id_number
            display.Detail = msg.caller_callee_id_number
          else
            display.Detail = msg.caller_callee_id_number
      line = $('<tr>', class: 'line')
      for key, value of display
        line.append($('<td>', class: key).text(value))

      $('#log tbody').prepend(line)
      # use scoping so we don't have to keep another storage of original
      # messages, will be GC'd with the DOM removal (or so I hope).
      line.click => @showDetail(line, msg)

  showDetail: (line, msg) ->
    $('#log .line').removeClass('active')
    line.addClass('active')
    detail = $('#detail')
    detail.text('')

    switch msg.tiny_action
      when 'call_start'
        general = $('<dl>')
        left = $('<dl>')
        right = $('<dl>')
        for key, value of msg
          unless key == "left" || key == "right" || key == "original"
            general.append($('<dt>').text(key))
            general.append($('<dd>').text(value))
        for key, value of msg.left
          left.append($('<dt>').text(key))
          left.append($('<dd>').text(value))
        for key, value of msg.right
          right.append($('<dt>').text(key))
          right.append($('<dd>').text(value))

        detail.append($('<h2>').text("General"))
        detail.append(general)
        detail.append($('<h2>').text("Left"))
        detail.append(left)
        detail.append($('<h2>').text("Right"))
        detail.append(right)
      else
        dl = $('<dl>')
        for key, value of msg
          dl.append($('<dt>').text(key))
          dl.append($('<dd>').text(value))
        detail.append(dl)

$ ->
  store.server = $('#server').text()
  store.server = "ws://" + location.hostname + ":8081/websocket" if store.server == ''
  store.agent = $('#agent_name').text()
  store.extension = store.agent.split('-')[0]

  store.ws = new Socket(new Controller())
  window.tcc_store = store # makes debugging sooo much easier :)

  $('#play').hide()
  $('#play, #pause').click (e) ->
    store.pause = !store.pause
    $('#play, #pause').toggle()

  setInterval ->
    $('#log .line:gt(100)').remove()
  , 1000
