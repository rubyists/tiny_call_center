store = {
  calls: {}
}

# Expand as you need it.
keyCodes = {
  F1:  112,
  F2:  113,
  F3:  114,
  F4:  115,
  F5:  116,
  F6:  117,
  F7:  118,
  F8:  119,
  F9:  120,
  F10: 121,
  F11: 122,
  F12: 123,
}

p = (msg) ->
  window.console?.debug?(msg)

showError = (msg) ->
  $('#error').text(msg)

class Call
  constructor: (@uuid, msg) ->
    @prepareDOM()
    action = (msg.cc_action || msg.event_name || msg.tiny_action).toLowerCase()
    this[action]?(msg)

  prepareDOM: ->
    @sel = store.call_template.clone()
    $('#calls').append(@sel)
    @dom = {
      state:     $('.state', @sel),
      cidNumber: $('.cid-number', @sel),
      cidName:   $('.cid-name', @sel),
      answered:  $('.answered', @sel),
      called:    $('.called', @sel),
    }

  call_start: (msg) ->
    p "call_start"

  initial_status: (msg) ->
    switch store.agent_ext
      when msg.caller_cid_num
        @dom.cidNumber.text(msg.callee_cid_num)
        @talkingStart(new Date(Date.parse(msg.call_created)))
      when msg.callee_cid_num
        @dom.cidNumber.text(msg.caller_cid_num)
        @dom.cidName.text(msg.caller_cid_name)
        @talkingStart(new Date(Date.parse(msg.call_created)))

  'bridge-agent-start': (msg) ->
    @dom.cidName.text(msg.cc_caller_cid_name)
    @dom.cidNumber.text(msg.cc_caller_cid_number)
    @talkingStart(new Date(Date.now()))

  'bridge-agent-end': (msg) ->
    @dom.cidName.text('')
    @dom.cidNumber.text('')
    @talkingEnd()

  channel_hangup: (msg) ->
    if msg.caller_unique_id == @uuid
      if msg.caller_destination_number == store.agent_ext
        @talkingEnd()
      else if msg.caller_caller_id_number == store.agent_ext
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
    @dom.cidNumber.text(cidNumber)
    @dom.cidName.text(cidName) if cidName?
    @dom.state.text('On A Call')
    @talkingStart(new Date(Date.now()))

  talkingStart: (answeredTime) ->
    return if @answered?
    @answered = answeredTime || new Date(Date.now())
    @answeredInterval = setInterval =>
      talkTime = parseInt((Date.now() - @answered) / 1000, 10)
      @dom.answered.text(
        "#{@answered.toLocaleTimeString()} (#{talkTime}s)"
      )
    , 1000

  talkingEnd: ->
    @answered = null
    clearInterval(@answeredInterval)
    setTimeout =>
      @dom.remove()
      delete store.calls[@uuid]
    , 1000

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

      if call = store.calls[uuid]
        action = (msg.cc_action || msg.event_name || msg.tiny_action).toLowerCase()
        call[action](msg)
      else
        call = new Call(uuid, msg)
        store.calls[uuid] = call

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
  store.call_template = $('#call-template').detach()

  $('#disposition button').click (event) ->
    alert $(event.target).text()
    # $('#disposition').hide()
    $('#disposition').focus()
    return false

  # $('#disposition').hide()

  $(document).keydown (event) ->
    keyCode = event.keyCode
    p event.keyCode
    bubble = true
    $('#disposition button').each (i, button) ->
      jbutton = $(button)
      keyName = jbutton.attr('accesskey')
      buttonKeyCode = keyCodes[keyName]
      if keyCode == buttonKeyCode
        event.stopPropagation?()
        event.preventDefault?()
        bubble = false
        jbutton.click()
    return bubble

  $('#disposition').focus()

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
