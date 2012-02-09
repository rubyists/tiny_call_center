#
# Misc
#

p = -> window.console?.debug?(arguments ...)
socket = null

statusOrStateToClass = (prefix, str) ->
  if str
    prefix + str.toLowerCase().replace(/\W+/g, "-").replace(/^-+|-+$/g, "")

initializeIsotope = (elt) ->
  elt.isotope(
    itemSelector: '.agent',
    layoutMode: 'fitRows',
    getSortData: {
      username: (e) ->
        e.find('.username').text()
      extension: (e) ->
        e.find('.extension').text()
      status: (e) ->
        s = e.find('.status').text()
        order =
          switch s
            when 'Available'
              0.7
            when 'Available (On Demand)'
              0.8
            when 'On Break'
              0.9
            when 'Logged Out'
              1.0

        extension = e.find('.extension').text()
        parseFloat("" + order + extension)
      idle: (e) ->
        [min, sec] = e.find('.time-since-status-change').text().split(':')
        (((parseInt(min, 10) * 60) + parseInt(sec, 10)) * -1)
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
# Views
#

Serenade.view 'queueList', """
ul[id="queues" class="dropdown-menu"]
  - collection @queues
      li
        a[href="#" event:click=showQueue!] @name
"""

Serenade.view 'agent', """
div.agent.span2[class=@statusClass event:dblclick=details!]
  span.extension @extension
  span.username @username
  span.state @state
  span.status @status
  span.time-since-status-change @timeSinceStatusChange
  span.queue @queue
  span.calls
    - collection @calls
      - view "call"
  span.more-calls @moreCalls
"""

Serenade.view 'call', """
div
  .cid-name @cid_name
  .cid-number @cid_number
  .arrow "&harr;"
  .destination @destination
  .time-of-call-start @created
  .answered @answered
  .queue-name @queueName
  .channel @channel
  .uuid @uuid
  a.calltap-uuid[href="#"]
    img[src="/images/ear.png"]
"""

Serenade.view 'agentDetail', """
.modal.fade
  .modal-header
    a.close[data-dismiss="modal"] "x"
    h3 @username " - " @id
  .modal-body
    ul.nav.nav-tabs
      li
        a[data-toggle="tab" href="#agentDetailOverview"] "Overview"
      li
        a[data-toggle="tab" href="#agentDetailStatusLog"] "Status Log"
      li
        a[data-toggle="tab" href="#agentDetailStateLog"] "State Log"
      li
        a[data-toggle="tab" href="#agentDetailCallHistory"] "Call History"
    .tab-content
      #agentDetailOverview.tab-pane.fade
        h2 "Status"
        .btn-group[data-toggle="buttons-radio"]
          button.btn.status-available[event:click=statusAvailable] "Available"
          button.btn.status-available-on-demand[event:click=statusAvailableOnDemand] "Available (On Demand)"
          button.btn.status-on-break[event:click=statusOnBreak] "On Break"
          button.btn.status-logged-out[event:click=statusLoggedOut] "Logged Out"

        h2 "State"
        .btn-group[data-toggle="buttons-radio"]
          button.btn.state-waiting[event:click=stateWaiting] "Ready"
          button.btn.state-idle[event:click=stateIdle] "Wrap Up"
      #agentDetailStatusLog.tab-pane
        "Loading Status Log..."
      #agentDetailStateLog.tab-pane
        "Loading State Log..."
      #agentDetailCallHistory.tab-pane
        "Loading Call History..."
        
  .modal-footer
    button.calltap
      i.icon-headphones
      "Tap"
"""

Serenade.view 'agentStatusLog', """
ul
  - collection @statuses
    li @created_at " : " @new_status
"""

Serenade.view 'agentStateLog', """
ul
  - collection @states
    li @created_at " : " @new_state
"""

Serenade.view 'agentCallLog', """
ul
  - collection @calls
    li @created_at " : " @new_state
"""

#
# Controllers
#

class AgentStatusLogController
Serenade.controller 'agentStatusLog', AgentStatusLogController

class AgentStateLogController
Serenade.controller 'agentStateLog', AgentStateLogController

class AgentCallLogController
Serenade.controller 'agentCallLog', AgentCallLogController

class AgentController
  details: ->
    view = $(Serenade.render('agentDetail', @model))
    view.on 'shown', =>
      statusClass = statusOrStateToClass('status-', @model.status)
      stateClass = statusOrStateToClass('state-', @model.state)
      $("button.#{statusClass}, button.#{stateClass}", view).
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
    target = $(event.target)
    socket.live 'queue_agents',
      queue: target.text(),
      success: (msg) =>
        p 'queue_agents', msg

Serenade.controller 'queueList', QueueController

#
# Models
#

class Call extends Serenade.Model
  @property 'legA'
  @property 'legB'
  @belongsTo 'agent', as: (-> Agent)

  constructor: -> @initialize(arguments ...) unless super

  initialize: ->
    p 'initialize Call', arguments ...

Agents = new Serenade.Collection([])

class Agent extends Serenade.Model
  @property 'extension'
  @property 'username'
  @property 'state'
  @property 'status'
  @property 'timeSinceStatusChange'
  @property 'queue'

  @hasMany 'calls', as: (-> Call)

  @property 'statusClass',
    get: (-> statusOrStateToClass('status-', @status)),
    dependsOn: ['status']

  constructor: -> @initialize(arguments ...) unless super

  initialize: ->
    p 'initialize Agent', arguments ...
    tmp = Serenade.render('agent', this)
    $('#agents').isotope('insert', $(tmp))

class Queue extends Serenade.Model
  @property 'name', serialize: true

$ ->
  initializeIsotope($('#agents'))

  server = $('#server').text()
  socket = new Rubyists.Socket(server: server)

  socket.onopen = ->
    socket.tag 'live', ->
      p('live', arguments ...)

    # apply updates to the agent
    socket.tag 'live:Agent', (msg) ->
      new Agent(msg.body)

    socket.tag 'live:Call:create', (msg) ->
      p 'live:Call:create', msg
      call = new Call(msg.body)
      p call
      p call.agent
      p call.agent.calls.push(call)
    socket.tag 'live:Call:update', (msg) ->
      p 'live:Call:update', msg
      call = new Call(msg.body)
      p call
      p call.agent
      p call.agent.calls
    socket.tag 'live:Call:delete', (msg) ->
      p 'live:Call:delete', msg
      toDelete = new Call(msg.body)
      toDeleteId = toDelete.id

      calls = toDelete.agent.calls

      pendingDeletion = []
      calls.forEach (call, index) ->
        pendingDeletion.push(call) if toDeleteId == call.id
      for call in pendingDeletion
        calls.delete(call)

    socket.live 'subscribe',
      name: $('#agent_name').text(),
      success: ->
        socket.live 'queues', success: (msg) ->
          queues = new Serenade.Collection(msg.queues)
          $('#queues').replaceWith(Serenade.render('queueList', queues: queues))
        socket.live 'agents',
          success: (msg) =>
            for agentMsg in msg.agents
              new Agent(agentMsg)
