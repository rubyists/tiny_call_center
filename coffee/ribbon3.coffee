p = -> window.console?.debug(arguments ...)
meta = {
  socket: null,
  calls: new Serenade.Collection([]),
}

Serenade.view('status', """
li#status.btn-group[data-toggle="buttons-radio"]
  button.btn.btn-success.available[event:click=statusAvailable!] "Available"
  button.btn.btn-info.on-break[event:click=statusOnBreak!] "On Break"
  button.btn.btn-primary.logged-out[event:click=statusLoggedOut!] "Logged Out"
""")

Serenade.view('state', """
li#state.btn-group[data-toggle="buttons-radio"]
  button.btn.btn-success.waiting[event:click=stateWaiting!] "Ready"
  button.btn.btn-info.in-a-queue-call[disabled="disabled"] "In a queue call"
  button.btn.btn-primary.idle[event:click=stateIdle!] "Wrap Up"
""")

Serenade.view('control', """
li#control
  button.btn.btn-primary[event:click=callMe!] "Call Me"
  button.btn.btn-primary[event:click=makeCall!] "Make Call"
  button.btn.btn-danger[event:click=logout!] "Logout"
""")

Serenade.view('calls', """
.container
  #calls.span12
    .row
      - collection @calls
        - view "call"
""")

Serenade.view('call', """
.call.alert.alert-info.span3
  a.close[data-dismiss="alert" event:click=hangup!] "\u2715"
  .row
    a.span1.transfer[href="#" event:click=transfer!] "Transfer"
    a.span1.dtmf[href="#" event:click=dtmf!] "DTMF"
    .span3.cid @display_cid
    .span1.queue @queue
    .span1.time @created_epoch
""")

class StatusController
  constructor: (@options) ->
    @agent = @options.agent
    @agent.bind 'change:status', (newStatus) =>
      switch newStatus
        when "Available"
          $('.available', @view).button('toggle')
        when "On Break"
          $('.on-break', @view).button('toggle')
        when "Logged Out"
          $('.logged-out', @view).button('toggle')

  statusAvailable: (event) ->
    event.stopPropagation()
    meta.socket.ribbon 'status', status: 'Available'
  statusOnBreak: ->
    event.stopPropagation()
    meta.socket.ribbon 'status', status: 'On Break'
  statusLoggedOut: ->
    event.stopPropagation()
    meta.socket.ribbon 'status', status: 'Logged Out'
Serenade.controller 'status', StatusController

class StateController
  constructor: (@options) ->
    @agent = @options.agent
    @agent.bind 'change:state', (newState) =>
      switch newState
        when "Idle" # Does nothing, no calls are given.
          $('.idle', @view).button('toggle')
        when "Waiting" # Ready to receive calls.
          $('.waiting', @view).button('toggle')
        when "Receiving" # A queue call is currently being offered to the agent.
          $('.receiving', @view).button('toggle')
        when "In a queue call" #  Currently on a queue call.
          $('.in-a-queue-call', @view).button('toggle')

  stateWaiting: ->
    event.stopPropagation()
    meta.socket.ribbon 'state', state: 'Waiting'
  stateIdle: ->
    event.stopPropagation()
    meta.socket.ribbon 'state', state: 'Idle'
Serenade.controller 'state', StateController

class ControlController
  callMe: ->
    meta.socket.ribbon 'call_me'
  makeCall: ->
    p "make call"
  logout: ->
    p "Log out"
Serenade.controller 'control', ControlController

class CallController
  hangup: (event) ->
    event.stopPropagation()
    meta.socket.ribbon 'hangup', uuid: @model.id, cause: 'EAR hangup'
  transfer: (event) ->
    p 'transfer', this
  dtmf: (event) ->
    p 'dtmf', this
Serenade.controller 'call', CallController

class Call extends Serenade.Model
  @property 'initializeRan'
  @property 'queue'
  @property 'display_cid'
  @property 'created_epoch'

  constructor: ->
    super(arguments ...)
    @initialize?(arguments ...) unless @initializeRan?
    @initializeRan = true

  initialize: ->
    p "Created Call:", this

class Agent extends Serenade.Model
  @property 'initializeRan'
  @property 'name'
  @property 'status'
  @property 'state'

  constructor: ->
    super(arguments ...)
    @initialize?(arguments ...) unless @initializeRan?
    @initializeRan = true

  initialize: ->
    p "Created Agent:", this

$ ->
  server = $('#console .server').text()
  meta.socket = new Rubyists.Socket(server: server)

  meta.socket.onopen = ->
    Serenade.clearCache()
    agent = new Agent(id: $('#console .extension').text(), name: $('#console .agent').text())

    meta.socket.tag 'ribbon:initialStatus', (msg) ->
      p 'init status', msg
      raw = msg.body
      agent.set(raw.agent)

      initialCalls = []
      for rawCall in raw.calls
        initialCalls.push(new Call(rawCall))
      meta.calls.update(initialCalls)

    meta.socket.tag 'ribbon:Call:create', (msg) ->
      p 'call create', msg
      raw = msg.body
      call = new Call(raw)
      meta.calls.push(call)
    meta.socket.tag 'ribbon:Call:update', (msg) ->
      p 'call update', msg
    meta.socket.tag 'ribbon:Call:delete', (msg) ->
      p 'call delete', msg
      toDelete = meta.calls.select (call) -> call.id == msg.body.uuid
      meta.calls.delete(call) for call in toDelete

    meta.socket.tag 'ribbon:Agent:update', (msg) ->
      p 'ribbon:Agent:update', msg
      agent.set(msg.body)
    meta.socket.tag 'ribbon', -> p('ribbon', arguments ...)
    meta.socket.ribbon 'subscribe',
      agent: agent.name,
      success: ->
        $('#status').replaceWith(Serenade.render('status', agent: agent))
        $('#state').replaceWith(Serenade.render('state', agent: agent))
        $('#control').replaceWith(Serenade.render('control'))
        $('#calls').replaceWith(Serenade.render('calls', calls: meta.calls))
        # Yay for tiny race conditions, there's a chance that we didn't get initial status yet.
        # The worst that can happen is that the buttons won't show initial status right.
        agent.trigger('change:status', agent.status)
        agent.trigger('change:state', agent.state)
