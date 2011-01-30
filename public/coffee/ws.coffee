store = {
  calls: {}
}

p = (msg) ->
  window.console?.debug?(msg)

showError = (msg) ->
  $('#error').text(msg)

class Call
  constructor: (@uuid, msg) ->
    @waitingStart()
    action = (msg.cc_action || msg.event_name || msg.ws_action).toLowerCase()
    this[action]?(msg)

  initial_status: (msg) ->
    switch store.agent_ext
      when msg.caller_cid_num
        $('#cid-number').text(msg.callee_cid_num)
        @talkingStart(new Date(Date.parse(msg.call_created)))
      when msg.callee_cid_num
        $('#cid-number').text(msg.caller_cid_num)
        $('#cid-name').text(msg.caller_cid_name)
        @talkingStart(new Date(Date.parse(msg.call_created)))

  'bridge-agent-start': (msg) ->
    $('#cid-name').text(msg.cc_caller_cid_name)
    $('#cid-number').text(msg.cc_caller_cid_number)
    @talkingStart(new Date(Date.now()))

  'bridge-agent-end': (msg) ->
    $('#cid-name').text('')
    $('#cid-number').text('')
    @talkingEnd()

  channel_hangup: (msg) ->
    if msg.caller_unique_id == @uuid
      if msg.caller_destination_number == store.agent_ext
        @hungupCall('Inbound Call', msg)
      else if msg.caller_caller_id_number == store.agent_ext
        @hungupCall('Outbound Call', msg)

  hungupCall: (direction, msg) ->
    $('#cid-number').text('')
    $('#cid-name').text('')
    $('#state').text('Waiting')
    @talkingEnd()

  channel_answer: (msg) ->
    if msg.caller_destination_number == store.agent_ext
      @answeredCall(
        'Inbound Call',
        msg.caller_caller_id_name,
        msg.caller_caller_id_number,
        msg.channel_call_uuid || msg.unique_id
      )
    else if msg.caller_caller_id_number == store.agent_ext
      @answeredCall(
        'Outbound Call',
        msg.caller_destination_number,
        msg.caller_callee_id_number,
        msg.channel_call_uuid || msg.unique_id
      )

  answeredCall: (direction, cidName, cidNumber, uuid) ->
    $('#cid-number').text(cidNumber)
    $('#cid-name').text(cidName) if cidName?
    $('#state').text('On A Call')
    @talkingStart(new Date(Date.now()))

  talkingStart: (answeredTime) ->
    return if @answered?
    @answered = answeredTime || new Date(Date.now())
    @answeredInterval = setInterval =>
      talkTime = parseInt((Date.now() - @answered) / 1000, 10)
      $('#answered').text(
        "#{@answered.toLocaleTimeString()} (#{talkTime}s)"
      )
    , 1000
    @waitingEnd()

  talkingEnd: ->
    @answered = null
    clearInterval(@answeredInterval)
    $('#answered').text('')
    @waitingStart()

  waitingStart: ->
    return if @called?
    @called = new Date(Date.now())
    @calledInterval = setInterval =>
      waitTime = parseInt((Date.now() - @called) / 1000, 10)
      $('#called').text(
        "#{@called.toLocaleTimeString()} (#{waitTime}s)"
      )
    , 1000

  waitingEnd: ->
    @called = null
    clearInterval(@calledInterval)
    $('#called').text('')

currentStatus = (tag) ->
  $('#status a').attr('class', 'inactive')
  tag.attr("class", "active")

agentStatusChange = (msg) ->
  switch msg.cc_agent_status.toLowerCase()
    when 'available'
      currentStatus($('#available'))
    when 'available (on demand)'
      currentStatus($('#available_on_demand'))
    when 'on break'
      currentStatus($('#on_break'))
    when 'logged out'
      currentStatus($('#logged_out'))

agentStateChange = (msg) ->
  $('#state').text(msg.cc_agent_state)

onMessage = (event) ->
  msg = JSON.parse(event.data)
  p msg
  switch msg.cc_action
    when 'agent-status-change'
      agentStatusChange(msg)
    when 'agent-state-change'
      agentStateChange(msg)
    else
      uuid = msg.uuid || msg.call_uuid || msg.channel_call_uuid || msg.unique_id
      p uuid

      if call = store.calls[uuid]
        action = (msg.cc_action || msg.event_name || msg.ws_action).toLowerCase()
        p action
        call[action](msg)
      else
        call = new Call(uuid, msg)
        store.calls[uuid] = call
  p store

onOpen = ->
  @send(JSON.stringify(method: 'subscribe', agent: store.agent_name))

onClose = ->
  $('#debug').text('Reconnecting...')
  setTimeout ->
    $('#debug').text('')
    setupWs()
  , 5000

onError = (event) ->
  showError(event.data)

setupWs = ->
  store.ws = new WebSocket(store.server)

  store.ws.onerror = onError
  store.ws.onclose = onClose
  store.ws.onopen = onOpen
  store.ws.onmessage = onMessage

$ ->
  store.server = $('#server').text()
  store.agent_name = $('#agent_name').text()
  store.agent_ext = store.agent_name.split('-', 2)[0]

  $('#disposition a').click (event) ->
    $('#disposition').hide()

  $('#disposition').hide()

  $(document).keydown (event) ->
    keyCode = event.keyCode
    bubble = true
    $('#disposition a').each (x, a) ->
      ja = $(a)
      code = parseInt(ja.attr('class').split('-')[1], 10)
      if code == keyCode
        event.stopPropagation?()
        event.preventDefault?()
        bubble = false
        ja.click()
    return bubble

  $('#status a').live 'click', (a) ->
    try
      curStatus = $('a[class=active]').text()
      store.ws.send(JSON.stringify(method: 'status', status: a.target.id, curStatus: curStatus))
    catch error
      showError error
    false

  setTimeout ->
    $(window).resize (event) ->
      localStorage.setItem 'agent.bar.width', top.outerWidth
      localStorage.setItem 'agent.bar.height', top.outerHeight
      return true
  , 100

  [width, height] = [localStorage.getItem('agent.bar.width'), localStorage.getItem('agent.bar.height')]
  top.resizeTo(width, height) if width && height

  setupWs()
