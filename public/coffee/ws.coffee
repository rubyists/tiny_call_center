store = {
  calls: {}
  send: (obj) -> @ws.send(JSON.stringify(obj))
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
  constructor: (local_leg, remote_leg, msg) ->
    @uuid = local_leg.uuid
    @local_leg = local_leg
    @remote_leg = remote_leg
    store.calls[@uuid] = this
    @prepareDOM()
    @talkingStart(new Date(Date.parse(msg.call_created)))

  prepareDOM: ->
    @sel = store.call_template.clone()
    @sel.attr('id', '')
    $('#calls').append(@sel)

    @dom = {
      state:             $('.state', @sel),
      cidNumber:         $('.cid-number', @sel),
      cidName:           $('.cid-name', @sel),
      answered:          $('.answered', @sel),
      called:            $('.called', @sel),
      destinationNumber: $('.destination-number', @sel),
      queueName:         $('.queue-name', @sel),
      uuid:              $('.uuid', @sel),
      channel:           $('.channel', @sel),
    }

    @dom.state.text('On A Call')
    @dom.cidNumber.text(@remote_leg.cid_number)
    @dom.cidName.text(@remote_leg.cid_name)
    @dom.destinationNumber.text(@remote_leg.destination_number)
    @dom.queueName.text(@local_leg.queue)
    @dom.uuid.text(@local_leg.uuid)
    @dom.channel.text(@local_leg.channel)

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

  answeredCall: (cidName, cidNumber, uuid) ->
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
    clearInterval(@answeredInterval)
    delete store.calls[@uuid]
    @askDisposition()

  askDisposition: ->
    $('#disposition button').one 'click', (event) =>
      p event
      jbutton = $(event.target)
      store.send(
        method: 'disposition',
        code:  jbutton.attr('id').split('-')[1],
        desc:  jbutton.attr('label'),
        left: @local_leg,
        right: @remote_leg,
      )
      @sel.remove()
      $('#disposition').hide()
      return false
    $('#disposition').show()

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

currentState = (tag) ->
  $('#state a').attr('class', 'inactive')
  tag.attr('class', 'active')

agentStateChange = (msg) ->
  switch msg.cc_agent_state.toLowerCase()
    when 'waiting'
      currentState($('#ready'))
    when 'idle'
      currentState($('#wrap_up'))

onMessage = (event) ->
  msg = JSON.parse(event.data)
  p msg
  switch msg.tiny_action
    when 'status_change'
      agentStatusChange(msg)
    when 'state_change'
      agentStateChange(msg)
    when 'call_start'
      extMatch = /(?:^|\/)(\d+)@/
      makeCall = (left, right, msg) ->
        new Call(left, right, msg) unless store.calls[left.uuid]

      if store.agent_ext == msg.left.channel?.match?(extMatch)[1]
        makeCall(msg.left, msg.right, msg)
      else if store.agent_ext == msg.right.channel?.match?(extMatch)[1]
        makeCall(msg.right, msg.left, msg)
      else if msg.right.destination == msg.right.channel?.match?(extMatch)[1]
        makeCall(msg.right, msg.left, msg)
      else if msg.left.destination == msg.left.channel?.match?(extMatch)[1]
        makeCall(msg.left, msg.right, msg)
      else if msg.left.cid_number == msg.left.channel?.match?(extMatch)[1]
        makeCall(msg.left, msg.right, msg)
      else if msg.right.cid_number == msg.right.channel?.match?(extMatch)[1]
        makeCall(msg.right, msg.left, msg)
    else
      for key, value of msg
        if /unique|uuid/.test(key)
          #p [key, value]
          if call = store.calls[value]
            call[msg.tiny_action]?(msg)
            return undefined

onOpen = ->
  store.send(method: 'subscribe', agent: store.agent_name)

onClose = ->
  $('#debug').text('Reconnecting...')
  setTimeout ->
    $('#debug').text('')
    setupWs()
  , 5000

onError = (event) ->
  showError(event.data)


agentWantsStatusChange = (a) ->
  curStatus = $('#status a[class=active]').text()
  store.send(
    method: 'status',
    status: a.target.id,
    curStatus: curStatus
  )
  false

agentWantsStateChange = (a) ->
  curState = $('#state a[class=active').text()
  store.send(
    method: 'state',
    state: a.target.id,
    curState: curState,
  )
  false

setupWs = ->
  store.ws = new WebSocket(store.server)

  store.ws.onerror = onError
  store.ws.onclose = onClose
  store.ws.onopen = onOpen
  store.ws.onmessage = onMessage

$ ->
  store.server = $('#server').text()
  store.agent_name = $('#agent_name').text()
  store.agent_ext = $('#agent_ext').text()
  store.call_template = $('#call-template').detach()

  $('#disposition').hide()

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

  $('#status a').live 'click', agentWantsStatusChange
  $('#state a').live 'click', agentWantsStateChange

  setTimeout ->
    $(window).resize (event) ->
      localStorage.setItem 'agent.bar.width', top.outerWidth
      localStorage.setItem 'agent.bar.height', top.outerHeight
      return true
  , 100

  [width, height] = [localStorage.getItem('agent.bar.width'), localStorage.getItem('agent.bar.height')]
  top.resizeTo(width, height) if width && height

  setupWs()
