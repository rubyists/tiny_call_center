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
  button.btn.btn-info.disabled.in-a-queue-call[disabled="disabled"] "In a queue call"
  button.btn.btn-primary.idle[event:click=stateIdle!] "Wrap Up"
""")

Serenade.view('control', """
li#control
  .btn-group
    button.btn.btn-primary.disabled.call-me[disabled="disabled" event:click=callMe!] "Call Me"
    button.btn.btn-primary[event:click=makeCallToggle!] "Make Call"
    button.btn.btn-danger.logout[event:click=logout!] "Logout"
""")

Serenade.view('makeCall', """
#makeCall.modal
  .modal-body
    a.close[data-dismiss="modal"] "\u2715"
    form.form-inline
      input.number.input-small[type="text" placeholder="Number to dial"]
      input.identifier.input-small[type="text" placeholder="Identifier"]
      button.btn[type="submit" event:click=makeCall!] "Make Call"
""")

Serenade.view('callTransfer', """
#callTransfer.modal
  .modal-body
    a.close[data-dismiss="modal"] "\u2715"
    form.form-inline
      input.number.input-small[type="text" placeholder="Destination"]
      button.btn[type="submit" event:click=callTransfer!] "Transfer Call"
""")

Serenade.view('callDTMF', """
#callDTMF.modal
  .modal-body
    a.close[data-dismiss="modal"] "\u2715"
    form.form-inline
      input.number.input-small[type="text" placeholder="DTMF Tones" event:input=sendDTMF!]
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
    .span1.time @duration
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
  constructor: (@options) ->
    @agent = @options.agent
    @agent.bind 'change:offHook', (newOffHook) =>
      p 'newOffHook', newOffHook
      if newOffHook
        $('.call-me', @view).removeAttr('disabled').removeClass('disabled')
      else
        $('.call-me', @view).attr('disabled', 'disabled').addClass('disabled')
  callMe: ->
    meta.socket.ribbon 'call_me'
  makeCallToggle: ->
    $(Serenade.render('makeCall')).modal()
  logout: ->
    p "Log out"
Serenade.controller 'control', ControlController

class MakeCallController
  makeCall: (event) ->
    number = $('input.number', @view).val()
    identifier = $('input.identifier', @view).val()
    meta.socket.ribbon 'call', number: number, identifier: identifier
    $(@view).modal('hide')
    setTimeout((=> $(@view).remove()), 1000)
Serenade.controller 'makeCall', MakeCallController

class CallTransferController
  callTransfer: (event) ->
    number = $('input.number', @view).val()
    meta.socket.ribbon 'transfer', number: number, uuid: @model.call.id
    $(@view).modal('hide')
    setTimeout((=> $(@view).remove()), 1000)
Serenade.controller 'callTransfer', CallTransferController

class CallDTMFController
  sendDTMF: (event) ->
    tones = $('input', @view).val()
    meta.socket.ribbon 'dtmf', uuid: @model.call.id, tones: tones
    $('input', @view).val('')
Serenade.controller 'callDTMF', CallDTMFController

class CallController
  hangup: (event) ->
    event.stopPropagation()
    meta.socket.ribbon 'hangup', uuid: @model.id, cause: 'EAR hangup'
  transfer: (event) ->
    $(Serenade.render('callTransfer', call: @model)).modal()
  dtmf: (event) ->
    $(Serenade.render('callDTMF', call: @model)).modal()
Serenade.controller 'call', CallController

class Call extends Serenade.Model
  @property 'initializeRan'
  @property 'queue'
  @property 'display_cid'
  @property 'created_epoch'
  @property 'duration'

  @property 'created',
    get: (-> @created_epoch * 1000),
    dependsOn: ['created_epoch']

  constructor: ->
    super(arguments ...)
    @initialize?(arguments ...) unless @initializeRan?
    @initializeRan = true

  initialize: ->
    p "Created Call:", this
    @timer = setInterval((=> @duration = Rubyists.formatInterval(@created)), 500)

class Agent extends Serenade.Model
  @property 'initializeRan'
  @property 'name'
  @property 'status'
  @property 'state'
  @property 'offHook'

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
      meta.calls.update((new Call(rawCall)) for rawCall in raw.calls)

    meta.socket.tag 'ribbon:Call:create', (msg) ->
      p 'call create', msg
      raw = msg.body
      call = new Call(raw)
      meta.calls.push(call)
    meta.socket.tag 'ribbon:Call:update', (msg) ->
      p 'call update', msg
    meta.socket.tag 'ribbon:Call:delete', (msg) ->
      p 'call delete', msg
      toDelete = meta.calls.select (call) -> call.id == msg.body.id
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
        $('#control').replaceWith(Serenade.render('control', agent: agent))
        $('#calls').replaceWith(Serenade.render('calls', calls: meta.calls))
        # Yay for tiny race conditions, there's a chance that we didn't get initial status yet.
        # The worst that can happen is that the buttons won't show initial status right.
        agent.trigger('change:status', agent.status)
        agent.trigger('change:state', agent.state)
        agent.trigger('change:offHook', agent.offHook)
