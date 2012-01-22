p = ->
  window.console?.debug(arguments ...)

class View extends Backbone.View
class Model extends Backbone.Model

class Agent extends Model
  url: 'Agent'
  persist: ['status', 'state']

class CallView extends View
  tagName: 'div'
  el: '#call'

  initialize: ->
    $(@el).hide()

class DispositionView extends View
  tagName: 'form'
  el: '#disposition'

  initialize: ->
    $(@el).hide()

class TransferView extends View
  tagName: 'form'
  el: '#transfer'

  initialize: ->
    $(@el).hide()

class OriginateView extends View
  tagName: 'form'
  el: '#originate'

  initialize: ->
    $(@el).hide()

class StatusView extends View
  tagName: 'ul'
  el: '#status'
  events: {
    'click .available': 'available'
    'click .on_break': 'on_break'
    'click .logged_out': 'logged_out'
    }
  statusMap: {
    'available': '.available',
    'available (on demand)': '.available',
    'on break': 'on_break',
    'logged out': 'logged_out',
  }

  initialize: ->
    @options.agent.bind('change:status', @render, this)

  render: ->
    status = @options.agent.get('status')
    klass = @statusMap[status.toLowerCase]
    @.$('button').removeClass('active')
    @.$(klass).addClass('active')
    this

  available: ->
    @options.agent.save(status: 'Available')
  on_break: ->
    @options.agent.save(status: 'On Break')
  logged_out: ->
    @options.agent.save(status: 'Logged Out')

class StateView extends View
  tagName: 'ul'
  el: '#state'

  initialize: ->
    @options.agent.bind('change:state', @render, this)

  render: ->
    state = @options.agent.get('state')
    klass = state.replace(/\s+/g, "_")
    @.$('button').removeClass('active')
    @.$(klass).addClass('active')
    this

class Ribbon extends View
  tagName: 'div'
  el: '#ribbon'

  initialize: ->
    _.bindAll(this, 'render')
    @agent = @options.agent
    @agent.bind('change', @render)
    @agent.fetch()

    @statusView = new StatusView(agent: @agent)
    @stateView = new StateView(agent: @agent)
    @dispositionView = new DispositionView(agent: @agent)
    @callView = new CallView(agent: @agent)
    @originateView = new OriginateView(agent: @agent)
    @transferView = new TransferView(agent: @agent)

  render: ->
    @dispositionView.render()
    this

Backbone.sync = Rubyists.BackboneWebSocketSync

class Socket extends Rubyists.Socket
  onopen: ->
    agent = new Agent(
      name: $('#agent_name').text(),
      extension: $('#agent_ext').text(),
    )
    ribbon = new Ribbon(agent: agent)
    ribbon.render()

window.Ribbon = Ribbon

$ ->
  server = $('#server').text()
  Rubyists.syncSocket = new Socket(server: server)
