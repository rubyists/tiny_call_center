#
# Misc
#

p = -> window.console?.debug?(arguments ...)
socket = null
isotopeRoot = null

searchToQuery = (raw) ->
  if /^[,\s]*$/.test(raw)
    $('#agents').isotope(filter: '*')
    return false

  query = []
  for part in raw.split(/\s*,\s*/g)
    part = part.replace(/'/, '')
    query.push(":contains('#{part}')")

  return query.join(", ")

statusOrStateToClass = (prefix, str) ->
  return unless str
  prefix + str.toLowerCase().replace(/\W+/g, "-").replace(/^-+|-+$/g, "")

queueToClass = (queue) ->
  return unless queue
  queue.toLowerCase().replace(/\W+/g, '_').replace(/^_+|_+$/g, "")

formatInterval = (start) ->
  total = parseInt((Date.now() - start) / 1000, 10)
  [hours, rest] = divmod(total, 60 * 60)
  [minutes, seconds] = divmod(rest, 60)
  sprintTime(hours, minutes, seconds)

sprintTime = ->
  parts = for arg in arguments
    num = parseInt(arg, 10)
    if num < 10
      '0' + num
    else
      num
  parts.join(":")

divmod = (num1, num2) ->
  [num1 / num2, num1 % num2]

initializeIsotope = (elt) ->
  $('#sort-agents a').click (event) ->
    sorter = $(event.target).attr('href').replace(/^#/, "")
    p sorter
    elt.isotope(sortBy: sorter)
    false
  elt.isotope(
    itemSelector: '.agent',
    layoutMode: 'fitRows',
    getSortData: {
      username: (e) ->
        e.find('.username').text()
      extension: (e) ->
        e.find('.extension').text()
      status: (e) ->
        ext = e.find('.extension').text()
        status = e.find('.status').text()

        order =
          switch status
            when 'Available'
              5
            when 'Available (On Demand)'
              6
            when 'On Break'
              7
            when 'Logged Out'
              8
            else
              4

        parseInt([order, ext].join(''), 10)
      idle: (e) ->
        parseInt(e.find('.lastStatusChange').text(), 10) * -1
    },
    sortBy: 'status',
  )

#
# View Helpers
#

Serenade.Helpers.liStatus = (klass, name, status) ->
  a = $('<a href="#"/>').text(name)
  if status == name
    a.addClass('active')
  p a
  a.get(0)

#
# Controllers
#

class AgentCallController
  calltap: ->
    socket.live 'uuid_calltap', uuid: @model.id, agent: @model.agent.id
Serenade.controller 'agentCall', AgentCallController

class AgentStatusLogController
Serenade.controller 'agentStatusLog', AgentStatusLogController

class AgentStateLogController
Serenade.controller 'agentStateLog', AgentStateLogController

class AgentCallLogController
Serenade.controller 'agentCallLog', AgentCallLogController

class AgentController
  details: ->
    # looks like a bug
    @model = @model.agent if @model.agent?
    view = $(Serenade.render('agentDetail', @model))
    view.on 'shown', =>
      statusClass = statusOrStateToClass('status-', @model.status)
      stateClass = statusOrStateToClass('state-', @model.state)
      $("button." + statusClass + ", button." + stateClass, view).
        button('reset').button('toggle')
    view.on 'hidden', -> view.remove()
    view.modal('show')
    $('.nav-tabs a:first', view).tab('show')

    $('a[href="#agentDetailStatusLog"]').on 'shown', =>
      socket.live 'agent_status_log', agent: @model.id, success: (logs) =>
        $('#agentDetailStatusLog').html(
          Serenade.render('agentStatusLog',
            statuses: (new Serenade.Collection(logs))))

    $('a[href="#agentDetailStateLog"]').on 'shown', =>
      socket.live 'agent_state_log', agent: @model.id, success: (logs) =>
        $('#agentDetailStateLog').html(
          Serenade.render('agentStateLog',
            states: (new Serenade.Collection(logs))))

    $('a[href="#agentDetailCallHistory"]').on 'shown', =>
      socket.live 'agent_call_log', agent: @model.id, success: (logs) =>
        $('#agentDetailCallLog').html(
          Serenade.render('agentCallLog',
            calls: (new Serenade.Collection(logs))))

Serenade.controller 'agent', AgentController

class AgentDetailController
  statusAvailable: (event) -> @submitStatus 'Available', $(event.target)
  statusAvailableOnDemand: (event) -> @submitStatus 'Available (On Demand)', $(event.target)
  statusOnBreak: (event) -> @submitStatus 'On Break', $(event.target)
  statusLoggedOut: (event) -> @submitStatus 'Logged Out', $(event.target)

  stateWaiting: (event) -> @submitState 'Waiting', $(event.target)
  stateIdle: (event) -> @submitState 'Idle', $(event.target)

  submitStatus: (name, button) ->
    button.button('loading')
    socket.live 'agent_status', agent: @model.id, status: name, success: ->
      button.button('reset').button('toggle')

  submitState: (name, button) ->
    button.button('loading')
    socket.live 'agent_state', agent: @model.id, state: name, success: ->
      button.button('reset').button('toggle')

Serenade.controller 'agentDetail', AgentDetailController

class QueueController
  showQueue: (event) ->
    queue = $(event.target).text()
    socket.live 'queue_agents',
      queue: queue,
      success: (msg) =>
        for tier in msg
          id = tier.agent.split("-")[0]
          new Agent(id: id, queue: tier.queue, state: tier.state)
        isotopeRoot.isotope(filter: "." + queueToClass(queue))

Serenade.controller 'queueList', QueueController

#
# Models
#

class Call extends Serenade.Model
  @property 'display_cid'
  @property 'created_epoch'
  @property 'duration'
  @property 'initializeRan'
  @belongsTo 'agent', as: (-> Agent)

  @property 'createdTime',
    get: (-> (new Date(@created)).toLocaleString()),
    dependsOn: ['created']

  @property 'created',
    get: (-> @created_epoch * 1000),
    dependsOn: ['created_epoch']

  constructor: (obj) ->
    super(arguments ...)
    @initialize(arguments ...) unless @initializeRan?

  initialize: ->
    @timer = setInterval((=> @duration = formatInterval(@created)), 1000)
    @bind('delete', (=> @onDelete(arguments ...)))
    @initializeRan = true

  onDelete: ->
    p 'onDelete', this
    clearInterval(@timer)
    @agent?.lastStatusChange = Date.now()

Agents = new Serenade.Collection([])
window.Agents = Agents

class Agent extends Serenade.Model
  @property 'extension'
  @property 'username'
  @property 'state'
  @property 'status'
  @property 'timeSinceStatusChange'
  @property 'lastStatusChange'
  @property 'queue'
  @property 'initializeRan'

  @hasMany 'calls', as: (-> Call)

  @property 'statusClass',
    get: (-> statusOrStateToClass('status-', @status)),
    dependsOn: ['status']

  @property 'queueClass',
    get: (-> queueToClass(@queue)),
    dependsOn: ['queue']

  constructor: (obj) ->
    super(arguments ...)
    @initialize(arguments ...) unless @initializeRan?

  initialize: ->
    @setupTimer()
    dom = @setupDOM()
    @setupBinds(dom)
    @initializeRan = true

  setupTimer: ->
    @lastStatusChange = Date.now()
    @timer = setInterval((=>
      @timeSinceStatusChange = formatInterval(@lastStatusChange)
    ), 1000)

  setupDOM: ->
    tag = $(Serenade.render('agent', this))
    tag.addClass(@statusClass)
    $('#agents').isotope('insert', tag)
    tag

  setupBinds: (tag) ->
    # @calls.bind 'change', (value) => p '@calls.change', value
    # @calls.bind 'add',    (value) => p '@calls.add', value
    # @calls.bind 'update', (value) => p '@calls.update', value
    # @calls.bind 'delete', => p('@calls.delete', arguments ...)

    # @bind 'change:calls', (value) => p 'agent.change:calls', value

    @bind 'change:status', (value) => @lastStatusChange = Date.now()
    @bind 'change:state', (value) => @lastStatusChange = Date.now()
    @calls.bind 'delete', (value) => @lastStatusChange = Date.now()
    @bind 'change:queue', (value) => tag.addClass(value)
    @bind 'change:lastStatusChange', (value) =>
      p 'change:lastStatusChange', value
      isotopeRoot.isotope('updateSortData', tag)
    @bind 'change:statusClass', (value) =>
      for klass in tag.attr('class').split(' ')
        tag.removeClass(klass) if /^status-/.test(klass)
      tag.addClass(value)

  # new or existing calls come in here.
  updateCall: (msg) ->
    id = msg.id
    @calls.forEach (call) ->
      if call.id == id
        return call.set(msg)
    call = new Call(msg, false)
    @calls.set(call.id, call)

class Queue extends Serenade.Model
  @property 'name', serialize: true

$ ->
  Serenade.useJQuery()
  isotopeRoot = $('#agents')
  initializeIsotope(isotopeRoot)

  $('#show-all-queues').on 'click', ->
    isotopeRoot.isotope(filter: "*")

  $('.navbar-search').on 'submit', (event) ->
    false

  $('#search').on 'input', (event) ->
    term = searchToQuery($(event.target).val())
    isotopeRoot.isotope(filter: term)
    false

  $('#search').on 'keyup', (event) =>
    if event.keyCode == 13
      event.preventDefault()

  server = $('#server').text()
  socket = new Rubyists.Socket(server: server)

  socket.onopen = ->
    socket.tag 'live', ->
      p('live', arguments ...)

    # apply updates to the agent
    socket.tag 'live:Agent', (msg) ->
      new Agent(msg.body)

    socket.tag 'live:Call:create', (msg) ->
      p 'live:Call:create', msg.body.agentId, msg.body.display_cid, msg.body.id, msg.body
      agentId = msg.body.agentId
      Agents.forEach (agent) ->
        if agent.id == agentId
          agent.updateCall(msg.body)
    socket.tag 'live:Call:update', (msg) ->
      p 'live:Call:update', msg.body.agentId, msg.body.display_cid, msg.body.id, msg.body
      agentId = msg.body.agentId
      Agents.forEach (agent) ->
        if agent.id == agentId
          agent.updateCall(msg.body)
    socket.tag 'live:Call:delete', (msg) ->
      p 'live:Call:delete', msg.body.agentId, msg.body.display_cid, msg.body.id, msg.body
      agents = Agents.select((agent) -> agent.id == msg.body.agentId)
      ids = [msg.body.id, msg.body.uuid, msg.body.call_uuid]
      for agent in agents
        calls = agent.calls.select (call) ->
          any = false
          for id in ids
            any = any || call.id == id
          any
        for call in calls
          p 'deleting', agent.calls.delete(call)

    socket.live 'subscribe',
      name: $('#agent_name').text(),
      success: ->
        socket.live 'queues', success: (msg) ->
          queues = new Serenade.Collection(msg.queues)
          $('#queues').replaceWith(Serenade.render('queueList', queues: queues))
        socket.live 'agents',
          success: (msg) =>
            for agentMsg in msg.agents
              if calls = agentMsg.calls
                delete call.agentId for call in calls
                agentMsg.calls = calls
              Agents.set(agentMsg.id, new Agent(agentMsg))
