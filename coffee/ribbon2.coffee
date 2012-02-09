p = ->
  window.console?.debug(arguments ...)

formatInterval = (start) ->
  total = parseInt((Date.now() - start) / 1000, 10)
  [hours, rest] = divmod(total, 60 * 60)
  [minutes, seconds] = divmod(rest, 60)
  sprintTime(hours, minutes, seconds)

sprintTime = ->
  parts = _.map arguments, (arg) ->
    if arg > 9
      parseInt(arg, 10).toString()
    else
      "0#{parseInt(arg, 10)}"
  parts.join(":")

divmod = (num1, num2) ->
  [num1 / num2, num1 % num2]

class View extends Backbone.View
  show: ->
    $(@el).show()
  hide: ->
    $(@el).hide()
class Model extends Backbone.Model
class Collection extends Backbone.Collection

class Agent extends Model
  url: 'Agent'

class Call extends Model
  url: 'Call'

class CallCollection extends Collection
  model: Call

class CallsView extends View
  tagName: 'div'
  el: '#calls'

  initialize: ->
    @calls = @options.calls
    @calls.bind('add', @addCall, this)
    @calls.bind('remove', @removeCall, this)
    @calls.bind('reset', (-> p 'reset Calls'))
    @calls.bind('change', @changeCall, this)
    @calls.bind('destroy', (-> p 'destroy Calls'))
    @calls.bind('error', (-> p 'error Calls'))
    $('#transfer').hide()
    @callTimer = setInterval =>
      @updateCallTimer()
    , 1000

  updateCallTimer: ->
    @calls.each (call) ->
      call.callView.updateCallTimer()

  addCall: (call, calls, options) ->
    p 'add Call', arguments ...
    call.callView = new CallView(ribbon: @options.ribbon, call: call)
    $(@el).append(call.callView.render().el)

  changeCall: (call, calls, options) ->
    p 'change Call', arguments ...

  removeCall: (call, calls, options) ->
    p 'remove Call', arguments ...
    call.callView.done()

class CallView extends View
  tagName: 'div'
  className: 'call'
  events: {
    'click .transfer': 'transfer',
    'click .hangup': 'hangup',
    'click .dtmf': 'dtmf',
  }
  template: _.template("""
<div class="call-control">
  <a href="#" title="Transfer" class="transfer">&#x27f9;</a>
  <a href="#" title="Dialpad" class="dtmf">&#x266f;</a>
  <a href="#" title="Hang up" class="hangup">&#x2715;</a>
</div>
<div class="call-data">
  <span class="name-and-number"><%- nameAndNumber %></span>
  <span class="answered"><%- answered %></span>
  <span class="queue"><%- queue %></span>
</div>
<form class="dtmf-form">
  <input type="dtmf" class="dtmf-input" />
</form>
  """)

  initialize: ->
    @call = @options.call
    @call.bind('change', @render, this)

    @localCallStart = new Date(Date.now())
    @serverCallStart = new Date(@call.get('created_epoch') * 1000)
    if @localCallStart.getTime() < @serverCallStart.getTime()
      @callStart = @localCallStart
    else
      @callStart = @serverCallStart

  # This here are a bit tricky, since we cannot guarantee that client and
  # server clock are in sync or which one is ahead.
  updateCallTimer: ->
    @.$('.answered').text("""
      #{@callStart.toLocaleTimeString()} #{formatInterval(@callStart)}
    """)

  transfer: ->
    view = new TransferView(ribbon: @options.ribbon, call: @call)
    view.render()

  dtmf: ->
    form = @.$('.dtmf-form')
    input = $('.dtmf-input', form)
    valueLen = input.val().length

    form.bind 'input', (event) =>
      value = input.val()
      newValueLen = value.length

      if newValueLen > valueLen
        @options.ribbon.sendMessage(
          body: {
            url: 'DTMF',
            uuid: @call.get('uuid'),
            tone: value.slice(valueLen, newValueLen),
          }
        )
      else if newValueLen == valueLen
        p 'no input'
      else if newValueLen < valueLen
        p 'deletion'
      valueLen = newValueLen

    form.slideToggle 'fast', =>
      if form.is(':visible')
        input.val('')
        input.focus()

  hangup: ->
    @options.ribbon.sendMessage(
      body: {
        url: 'Hangup',
        uuid: @call.get('uuid'),
        cause: "Ribbon hangup",
      }
    )

  render: ->
    $(@el).html(@template(
      nameAndNumber: @call.get('display_name_and_number'),
      answered: @call.get('callstate'), # this should be the time counter
      queue: [@call.get('queue')].join(), # the to_s equivalent...
    ))
    this

  done: ->
    # if it's a queue call, ask for disposition.
    if queue = @call.get('queue')
      $('#disposition button').one 'click', (event) =>
        jbutton = $(event.target)
        @options.ribbon.sendMessage(
          body: {
            url: 'Disposition',
            code: jbutton.attr('id').split('-')[1],
            desc: jbutton.attr('label'),
            uuid: @call.id,
          }
        )
        $('#disposition').hide()
        @remove()
        delete @call.callView
        false
      $('#disposition').show()
    else
      @remove()
      delete @call.callView

class DispositionView extends View
  tagName: 'form'
  el: '#disposition'

  initialize: ->
    @hide()


class TransferView extends View
  tagName: 'form'
  el: '#transfer'
  events: {
    'click .transfer': 'transfer',
    'click .close': 'close',
  }

  initialize: ->
    @hide()

  render: ->
    @show()

  transfer: ->
    @options.ribbon.sendMessage(
      body: {
        url: 'Transfer',
        dest: @.$('#transfer-dest').val(),
        uuid: @options.call.get('call_uuid'),
      }
    )
    @hide()

  close: ->
    @hide()

class OriginateView extends View
  tagName: 'form'
  el: '#originate-form'
  events: {
    'click .close': 'hide',
    'click .call': 'call',
  }

  initialize: ->
    @hide()

  call: ->
    @options.ribbon.sendMessage(
      body: {
        url: 'Originate',
        dest: @.$('#originate-dest').val(),
        identifier: $('#originate-identifier').val()
      }
    )
    @hide()

class StatusView extends View
  tagName: 'ul'
  el: '#status'
  events: {
    'click .available': 'available'
    'click .on_break': 'onBreak'
    'click .logged_out': 'loggedOut'
    }
  statusMap: {
    'available': '.available',
    'available (on demand)': '.available',
    'on break': '.on_break',
    'logged out': '.logged_out',
  }

  initialize: ->
    @options.agent.bind('change:status', @render, this)

  render: ->
    status = @options.agent.get('status')
    klass = @statusMap[status.toLowerCase()]
    @.$('button').removeClass('active')
    @.$(klass).addClass('active')
    this

  available: ->
    @options.agent.save(status: 'Available')
  onBreak: ->
    @options.agent.save(status: 'On Break')
  loggedOut: ->
    @options.agent.save(status: 'Logged Out')

class StateView extends View
  tagName: 'ul'
  el: '#state'
  events: {
    'click .Waiting': 'waiting',
    'click .In_a_queue_call': 'inQueue',
    'click .Idle': 'idle',
  }

  initialize: ->
    @options.agent.bind('change:state', @render, this)

  render: ->
    state = @options.agent.get('state')
    klass = "." + state.replace(/\s+/g, "_")
    @.$('button').removeClass('active')
    @.$(klass).addClass('active')
    this

  waiting: ->
    @options.agent.save(state: 'Waiting')
  inQueue: ->
    @options.agent.save(state: 'In a queue call')
  idle: ->
    @options.agent.save(state: 'Idle')

class Ribbon extends View
  tagName: 'div'
  el: '#ribbon'
  events: {
    'click #originate': 'showOriginate',
    'click #callme': 'callMe',
  }

  initialize: ->
    _.bindAll(this, 'render')
    @agent = @options.agent
    @calls = @options.calls
    @agent.bind('change', @render)

    @statusView = new StatusView(agent: @agent)
    @stateView = new StateView(agent: @agent)
    @dispositionView = new DispositionView(agent: @agent)
    @callsView = new CallsView(agent: @agent, calls: @calls, ribbon: this)
    @originateView = new OriginateView(ribbon: this)

  render: ->
    @dispositionView.render()
    this

  showOriginate: ->
    @originateView.show()

  callMe: ->
    @sendMessage(body: {url: 'CallMe'})

  sendMessage: ->
    @options.socket.say(arguments ...)

window.Ribbon = Ribbon

$ ->
  calls = new CallCollection()
  agent = new Agent(
    name: $('#agent_name').text(),
    extension: $('#agent_ext').text(),
  )
  ribbon = new Ribbon(agent: agent, calls: calls)

  socket = new Rubyists.BackboneWebSocket(
    server: $('#server').text(),
    onopen: ->
      ribbon.options.socket = socket
      agent.fetch(
        success: (-> p('Agent success', arguments ...)),
        error: (-> p('Agent error', arguments ...)),
      )
      ribbon.render()
  )
  Backbone.sync = socket.sync()

  socket.listen 'pg', (msg) ->
    switch msg.kind
      when 'agent_update'
        agent.set(msg.body)
      when 'call_create'
        msg.body.id = msg.body.uuid
        if got = calls.get(msg.body.id)
          got.set(msg.body)
        else
          calls.create(msg.body)
      when 'call_update'
        calls.get(msg.body.uuid).set(msg.body)
      when 'call_delete'
        call = calls.get(msg.body.uuid)
        calls.remove(call)

  setTimeout ->
    $(window).resize (event) ->
      localStorage.setItem 'agent.bar.width', top.outerWidth
      localStorage.setItem 'agent.bar.height', top.outerHeight
      return true
  , 500

  [width, height] = [localStorage.getItem('agent.bar.width'), localStorage.getItem('agent.bar.height')]
  top.resizeTo(width, height) if width && height
