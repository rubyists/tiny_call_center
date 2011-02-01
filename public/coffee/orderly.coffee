log = (msg) ->
  window.console?.debug?(msg)

statusOrStateToClass = (str) ->
  str.toLowerCase().replace(/\W+/g, "-").replace(/^-+|-+$/g, "")

divmod = (num, mod) ->
  [Math.floor(num / mod), Math.floor(num % mod)]

timeFragmentPad = (fragment) ->
  if fragment > 9 then fragment else "0#{fragment}"

secondsToTimestamp = (given) ->
  [rest, seconds] = divmod(given, 60)
  [rest, minutes] = divmod(rest, 60)
  hours = Math.floor(rest / 60)

  (timeFragmentPad(fragment) for fragment in [hours, minutes, seconds]).join(':')

class Agent
  constructor: (@name) ->
    @id = "##{name}"
    @initTr()
    @setCalledTime(new Date(Date.now()))

  initTr: ->
    $('#agents').append """
<div class='agent' id='#{@name}'>
  <div class="extension-name">
    <span class='extension'></span>
    <span class='name'></span>
  </div>
  <span class='status'></span>
  <span class='state'></span>
  <div class="cid">
    <span class='cid-name'></span>
    <span class='cid-number'></span>
  </div>
  <span class='answered'></span>
  <span class='called'></span>
  <span class='queue'></span>
</div>
    """

    $("#{@id} .status").click (event) =>
      dialog = $("#status-dialog").clone(true)
      dialog.attr('id', '')
      dialog.addClass(@id[1..])
      dialog.find('.agent-name').text(@id[1..])
      active = dialog.find('.status a').filter (i,elt) =>
        $(elt).text() == @status
      active.addClass('active')

      dialog.dialog(
        autoOpen: true,
        title: "#{@extension} #{@name} Details",
        modal: false,
        open: (event, ui) =>
          dialog.find('.status .active').focus()
        close: (event, ui) ->
          dialog.remove()
      )


  initializeFromMsg: (name, msg) ->
    @setNameExtension(name)
    @setQueue(msg.cc_queue)
    @setState(msg.state || 'Waiting')
    @setStatus(msg.status || 'Available')

    if msg.call_created?
      log [msg.caller_cid_num, msg.caller_cid_name, msg.callee_cid_num, msg.caller_dest_num]
      log @extension
      date = new Date(Date.parse(msg.call_created))
      if msg.caller_dest_num == @extension
        log [1, msg.caller_cid_num, msg.caller_cid_name]
        @answeredCall('Inbound Call', msg.caller_cid_name, msg.caller_cid_num, date, msg.call_uuid)
      else
        log [0, msg.caller_dest_num]
        @answeredCall('Outbound Call', null, msg.caller_dest_num, date, msg.call_uuid)
    else if msg.last_bridge_end?
      date = new Date(Date.parse(msg.last_bridge_end))
      @setCalledTime(date) if date.getFullYear() > 2009

  answeredCall: (direction, cidName, cidNumber, answeredTime, uuid) ->
    log "Answered Call #{direction}, #{cidName}, #{cidNumber}, #{uuid}"
    answeredTime = if answeredTime? then answeredTime else new Date(Date.now())
    @setState(direction)
    @setCid(cidName, cidNumber, uuid)
    @setAnsweredTime(answeredTime)
    #div = $("#{@id}").detach()
    #$('#agents').prepend(div)

  hungupCall: (direction, msg) ->
    @setState('Waiting')
    @setCidName('')
    @setCidNumber('')
    @setAnsweredTime()
    @setCalledTime(new Date(Date.now()))

  adjustVisibility: (effect, speed) ->
    if @isVisible
      $("#{@id}:hidden").show(effect, speed)
    else
      $("#{@id}:visible").hide(effect, speed)

  tick: ->
    if @answeredTime?
      @setTalkTime parseInt((Date.now() - @answeredTime) / 1000, 10)
    else if @calledTime?
      @setWaitTime parseInt((Date.now() - @calledTime  ) / 1000, 10)

  setAnsweredTime: (@answeredTime) ->
    if answeredTime?
      @tick()
    else
      $("#{@id} .answered").text('')

  setCalledTime: (@calledTime) ->
    if calledTime?
      @tick()
    else
     $(@id).children('.called').text('')

  setTalkTime: (@talkTime) ->
    tag = $("#{@id} .answered")
    if talkTime?
      tag.text(secondsToTimestamp(talkTime))
    else
      tag.text(secondsToTimeStamp(@answeredTime.getTime()))

  setWaitTime: (@waitTime) ->
    tag = $("#{@id} .called")
    if waitTime?
      tag.text(secondsToTimestamp(waitTime))
    else
      tag.text('')

  setStatus: (@status) ->
    baseclass = statusOrStateToClass(status)
    $("#{@id} .status").removeClass().addClass("status ui-state-hover #{baseclass}")
    $(".status-dialog.#{@id[1..]} .status a").removeClass('active')
    $(".status-dialog.#{@id[1..]} .status a.#{baseclass}").addClass('active')

  setState: (@state) ->
    tag = $("#{@id} .state")
    switch state.toLowerCase()
      when 'in a queue call'
        tag.removeClass().addClass('state')
        tag.text('Q')
      when 'inbound call'
        tag.removeClass().addClass('state ui-icon ui-icon-circle-arrow-w')
        unless tag.text == 'Q'
          tag.text(state)
      when 'waiting', 'idle'
        tag.removeClass().addClass('state ui-icon ui-icon-clock')
        tag.text('')
      when 'outbound call'
        tag.removeClass().addClass('state ui-icon ui-icon-circle-arrow-e')
        tag.text(state)
      else
        tag.text(state)

  setQueue: (@queue) ->
    $("#{@id} .queue").text(queue)

  setCid: (name, number, uuid) ->
    if name? and number? and uuid?
      if name == number
        @setCidName('')
        @setCidNumber(number,uuid)
      else
        @setCidName(name)
        @setCidNumber(number, uuid)
    else
      @setCidName('')
      @setCidNumber(number,uuid)

  setCidName: (@cidName) ->
    $("#{@id} .cid-name").text(cidName)

  setCidNumber: (@cidNumber, uuid) ->
    $("#{@id} .cid-number").html("<a class=\"calltaptoo\" name=\"#{@name}\" href=\"#\" rel=\"#{@extension}\" title=\"#{uuid}\">#{cidNumber}</a>")

  setName: (@name) ->
    $("#{@id} .name").text(name)

  setExtension: (@extension) ->
    $("#{@id} .extension").text(extension)

  setNameExtension: (nameExtension) ->
    [ext, name] = nameExtension.split('-', 2)
    @setExtension(ext)
    @setName(name.replace(/_/g, ' '))

  "bridge-agent-start": (msg) ->
    @setQueue(msg.cc_queue)
    @setCidName(msg.cc_caller_cid_name)
    @setCidNumber(msg.cc_caller_cid_number)
    @setAnsweredTime(new Date(Date.now()))

  "bridge-agent-end": (msg) ->
    @setAnsweredTime()
    @setCalledTime(new Date(Date.now()))
    @setCidName('')
    @setCidNumber('')
    @setQueue('')

  "agent-state-change": (msg) ->
    @setState(msg.cc_agent_state)

    switch @state
      when "Receiving"
        @setCalledTime(@calledTime || new Date(Date.now()))
      when "In a queue call"
        @setAnsweredTime(new Date(Date.now()))

  "agent-status-change": (msg) ->
    @setStatus(msg.cc_agent_status)

Agent.all = {}

Agent.withExtension = (extension) ->
  return if !extension? || extension.length > 4
  for key, agent of Agent.all
    return agent if agent.extension == extension
  return

Agent.findOrCreate = (msg) ->
  name = if msg.cc_agent? then msg.cc_agent else msg.name
  agent = Agent.all[name]
  if !agent? and name
    agent = new Agent(name)
    agent.initializeFromMsg(name, msg)
    Agent.all[name] = agent
  agent

updateDeltas = ->
  agent.tick() for key, agent of Agent.all
  return # avoid returning comprehension

changeStatus = (event) ->
  ws = event.data
  a = $(event.target)
  agentId = a.closest('.status-dialog').find('.agent-name').text()
  status = statusOrStateToClass(a.text()).replace(/-/g, '_')
  ws.send(JSON.stringify(method: "status_of", agent: agentId, status: status))
  false

callTap = (event) ->
  ws = event.data
  a = $(event.target)
  agentId = a.closest('.status-dialog').find('.agent-name').text()
  self = $('#agent_name').text()
  ws.send(JSON.stringify(method: 'calltap', agent: agentId, tapper: self))

callTapToo = (event) ->
  try
    ws = event.data
    extension = this.rel
    uuid = this.title
    phoneNumber = this.text
    name = this.name
    tapper = $('#agent_name').text()
    log "tapping #{name}: #{extension} <=> #{phoneNumber} (#{uuid}) by #{tapper}"
    ws.send(JSON.stringify(
      method: 'calltaptoo',
      name: name,
      extension: extension,
      tapper: tapper,
      uuid: uuid,
      phoneNumber: phoneNumber
    ))
  catch error
    log error

  false

withLabel = (name, fun) ->
  json = localStorage.getItem('labels')

  if json?
    labels = JSON.parse(json)
    label = labels[name] || {}
    labels[name] = label
  else
    labels = {}
    label = {}
    labels[name] = label

  result = fun(label)

  actual = {}
  for name, label of labels
    actual[name] = label if /^[a-zA-Z][a-zA-Z0-9_-]*$/.test(name)

  localStorage.setItem('labels', JSON.stringify(actual))

  refreshAspects()
  result

dropped = (agentId, labelName) ->
  if labelName == 'Trash'
    activeLabelName = window.location.hash[1..]
    withLabel activeLabelName, (label) ->
      delete label[agentId]
      true

    showAspect(activeLabelName)
  else
    withLabel labelName, (label) ->
      label[agentId] = true

refreshAspects = ->
  labels = JSON.parse(localStorage.getItem('labels'))
  $('.aspects .droppable').detach()
  for name, label of labels
    tag = $("<li class='droppable'><a href='##{name}'>#{name}</a></li>")
    tag.insertBefore($('.aspects .trash'))
  $('.aspects .droppable, .aspects .trash').droppable(
    activeClass: "ui-state-active",
    hoverClass: "ui-state-hover",
    drop: (event, ui) ->
      agentId = ui.draggable[0].id
      labelName = $(this).text()
      dropped(agentId, labelName)
  )


showAspect = (labelName) ->
  $('.aspects li').removeClass('active')
  $('.aspects li').each (i, li) ->
    $(li).addClass('active') if $(li).text() == labelName

  [effect, speed] = ['fade', 'slow']
  if labelName == ''
    $('.agent:hidden').show(effect, speed)
    $('.aspects .trash:visible').hide(effect, speed)
  else
    $('.aspects .trash:hidden').show(effect, speed)
    withLabel labelName, (label) ->
      agents = Agent.all
      agent.isVisible = false for key, agent of agents
      for agentId, value of label
        if agent = agents[agentId]
          agent.isVisible = true
      agent.adjustVisibility(effect, speed) for key, agent of agents
      true
  true # don't store

syncSettingsFromAspects = ->
  $('#settings-dialog .aspects li').detach()
  for name, label of JSON.parse(localStorage.getItem('labels'))
    $('#settings-dialog .aspects').append($("""
      <li>#{name}<span class="ui-icon ui-icon-trash"></span></li>
    """))

onMessage = (event) ->
  msg = JSON.parse(event.data)
  debuggers = /2616|2602|2613/

  if msg.agents
    log msg.agents
    for agent in msg.agents
      Agent.findOrCreate(agent)
  else if agent = Agent.findOrCreate(msg)
    agent[msg.cc_action].apply?(agent, [msg])
  else if msg.event_name == 'CHANNEL_HANGUP'
    if debuggers.test(msg.caller_destination_number) || debuggers.test(msg.caller_caller_id_number)
      log "HANGUP"
      log event.data
    if agent = Agent.withExtension(msg.caller_destination_number)
      agent.hungupCall('Inbound Call', msg)
    if agent = Agent.withExtension(msg.caller_caller_id_number)
      agent.hungupCall('Outbound Call', msg)
  else if msg.event_name == 'CHANNEL_ANSWER'
    if debuggers.test(msg.caller_destination_number) || debuggers.test(msg.caller_caller_id_number)
      log "ANSWER"
      log event.data
    if agent = Agent.withExtension(msg.caller_destination_number)
      agent.answeredCall('Inbound Call', msg.caller_caller_id_name, msg.caller_caller_id_number, null, msg.channel_call_uuid)
    if agent = Agent.withExtension(msg.caller_caller_id_number)
      agent.answeredCall('Outbound Call', msg.caller_callee_id_name, msg.caller_callee_id_number, null, msg.channel_call_uuid)
  return

onOpen = (event) ->
  agent = $('#agent_name').text()
  @send(JSON.stringify(method: 'subscribe', agent: agent))
  @intervalId = setInterval(updateDeltas, 1000)
  refreshAspects()

onClose = (event) ->
  setTimeout(setupWs, 3000)
  clearInterval(@intervalId)

setupWs = ->
  server = $('#server').text()
  ws = new WebSocket(server)

  ws.onmessage = onMessage
  ws.onopen = onOpen
  ws.onclose = onClose

  $('#total-reset').click (event) ->
    localStorage.clear()
    refreshAspects()
    syncSettingsFromAspects()
    false

  $('.status-dialog .status a').die('click').live('click', ws, changeStatus)
  $('.status-dialog .calltap').die('click').live('click', ws, callTap)
  $('a.calltaptoo').die('click').live('click', ws, callTapToo)

$ ->
  setupWs()

  $('#agents').sortable()
  $('#agents').disableSelection()

  $('#settings-dialog .tabs').tabs()

  $(window).bind 'hashchange', (event) ->
    hash = event.target.location.hash
    showAspect(hash[1..])

  $('#settings-dialog .aspects .ui-icon-trash').live 'click', (event) ->
    labelName = $(event.target).parent().text()
    json = localStorage.getItem('labels')
    labels = JSON.parse(json)
    delete labels[labelName]
    localStorage.setItem('labels', JSON.stringify(labels))
    refreshAspects()
    syncSettingsFromAspects()
    false

  $('#settings-dialog').dialog(
    autoOpen: false,
    title: 'Settings'
    modal: true,
    open: syncSettingsFromAspects
  )
  $('nav .settings').click (event) ->
    $('#settings-dialog').dialog('open')

  $('#settings-dialog .add-aspect button').click (event) ->
    input = $('#input-text-add-aspect')
    labelName = input.val()
    withLabel labelName, (label) -> true
    input.val('')
    syncSettingsFromAspects()
    false
