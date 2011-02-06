p = () ->
  window.console?.debug?(arguments)

store = {
  agents: {},
  stateMapping: {
    Idle: 'Wrap Up',
    Waiting: 'Ready',
  }
}

statusOrStateToClass = (prefix, str) ->
  prefix + str.toLowerCase().replace(/\W+/g, "-").replace(/^-+|-+$/g, "")

class Socket
  constructor: (@controller) ->
    @connect()

  connect: () ->
    @ws = new WebSocket(store.server)
    @ws.onopen = =>
      clearInterval(@reconnectInterval) if @reconnectInterval
      @say(method: 'subscribe', agent: store.agent)

    @ws.onmessage = (message) =>
      data = JSON.parse(message.data)
      p "onMessage", data
      @controller.dispatch(data)

    @ws.onclose = =>
      p "Closing WebSocket"
      @reconnectInterval = setInterval =>
        p "Reconnect"
        @connect()
      , 1000

    @ws.onerror = (error) =>
      p "WebSocket Error:", error

  say: (obj) ->
    p "Socket.send", obj
    @ws.send(JSON.stringify(obj))


class Controller
  dispatch: (msg) ->
    if method = msg.method
      @["got_#{method}"].apply(this, msg.args)
    else if action = msg.tiny_action
      store.agents[msg.cc_agent]["got_#{action}"](msg)

  got_queues: (queues) ->
    $('#nav-queues').html('')
    for queue in queues
      li = $('<li>')
      a = $('<a>', href: '#').text(queue.name)
      li.append(a)
      $('#nav-queues').append(li)

  got_agent_list: (agents) ->
    for rawAgent in agents
      agent = store.agents[rawAgent.name] || new Agent(rawAgent.name)
      agent.fillFromAgent(rawAgent)

  got_agents_of: (queue, tiers) ->
    agent.hide() for name, agent of store.agents

    for tier in tiers
      agent = store.agents[tier.agent] || new Agent(tier.agent)
      agent.fillFromTier(tier)
      agent.show()

  got_call_start: (msg) ->
    store.agents[msg.cc_agent].got_call_start(msg)

  got_channel_hangup: (msg) ->
    store.agents[msg.cc_agent].got_channel_hangup(msg)


class Call
  constructor: (@agent, @localLeg, @remoteLeg, msg) ->
    @uuid = localLeg.uuid
    @klass = "call-#{@uuid}"
    @createDOM()
    @renderInAgent()
    @renderInDialog()
    @agent.calls[@uuid] = this

  createDOM: ->
    @dom = store.protoCall.clone()
    @dom.attr('class', @klass)
    $('.state', @dom).text('On A Call')
    $('.cid-number', @dom).text(@remoteLeg.cid_number)
    $('.cid-name', @dom).text(@remoteLeg.cid_name)
    $('.destination-number', @dom).text(@remoteLeg.destination_number)
    $('.queue-name', @dom).text(@localLeg.queue)
    $('.uuid', @dom).text(@localLeg.uuid)
    $('.channel', @dom).text(@localLeg.channel)
    @dialogDOM = @dom.clone(true)

  hangup: (msg) ->
    delete @agent.calls[@uuid]
    @dom.slideUp("normal", -> $(this).remove())
    @dialogDOM.remove()

  renderInAgent: ->
    $('.calls', @agent.dom).append(@dom)

  renderInDialog: ->
    $('.calls', @agent.dialog).append(@dialogDOM) if @agent.dialog?

  calltap: ->
    p "tapping #{@agent.name}: #{@agent.extension} <=> #{@remoteLeg.cid_number} (#{@localLeg.uuid}) by #{store.agent}"
    store.ws.say(
      method: 'calltap_too',
      tapper: store.agent,
      name: @agent.name,
      extension: @agent.extension,
      uuid: @localLeg.uuid,
      phoneNumber: @remoteLeg.cid_number,
    )

  tick: ->


class Agent
  constructor: (@name) ->
    @meta = {}
    @calls = {}
    store.agents[@name] = this
    @createDOM()

  createDOM: ->
    @dom = store.protoAgent.clone()
    @dom.attr('id', "agent-#{@name}")
    $('.name', @dom).text(@name)
    $('#agents').append(@dom)
    @dom.show()

  fillFromAgent: (d) ->
    @setName(d.name)
    @setState(d.state)
    @setStatus(d.status)
    @setUsername(d.username)
    @setExtension(d.extension)

    @busy_delay_time = d.busy_delay_time
    @class_answered = d.class_answered
    @contact = d.contact
    @last_bridge_end = new Date(Date.parse(d.last_bridge_end))
    @last_bridge_start = new Date(Date.parse(d.last_bridge_start))
    @last_offered_call = new Date(Date.parse(d.last_offered_call))
    @last_status_change = new Date(Date.parse(d.last_status_change))
    @max_no_answer = d.max_no_answer
    @no_answer_count = d.no_answer_count
    @ready_time = d.ready_time
    @reject_delay_time = d.reject_delay_time
    @system = d.system
    @talk_time = d.talk_time
    @type = d.type
    @uuid = d.uuid
    @wrap_up_time = d.wrap_up_time

  fillFromTier: (d) ->
    @setName(d.agent)
    @setState(d.state)
    @level = d.level
    @position = d.position
    @queue = d.queue

  got_call_start: (msg) ->
    extMatch = /(?:^|\/)(\d+)[@-]/
    leftMatch = msg.left.channel?.match?(extMatch)?[1]
    rightMatch = msg.right.channel?.match?(extMatch)?[1]

    if @extension == leftMatch
      @makeCall(msg.left, msg.right, msg)
    else if @extension == rightMatch
      @makeCall(msg.right, msg.left, msg)
    else if msg.right.destination == rightMatch
      @makeCall(msg.right, msg.left, msg)
    else if msg.left.destination == leftMatch
      @makeCall(msg.left, msg.right, msg)
    else if msg.left.cid_number == leftMatch
      @makeCall(msg.left, msg.right, msg)
    else if msg.right.cid_number == rightMatch
      @makeCall(msg.right, msg.left, msg)

  makeCall: (left, right, msg) ->
    new Call(this, left, right, msg) unless @calls[left.uuid]

  got_channel_hangup: (msg) ->
    for key, value of msg
      if /unique|uuid/.test(key)
        if call = @calls[value]
          call.hangup(msg)
          return undefined

  got_status_change: (msg) ->
    @setStatus(msg.cc_agent_status)

  got_state_change: (msg) ->
    @setState(msg.cc_agent_state)

  setName: (@name) ->
    @dom.attr('id', "agent-#{name}")
    $('.name', @dom).text(name)

  setState: (@state) ->
    unless alias = store.stateMapping[state]
      return
    state = alias
    targetKlass = statusOrStateToClass("state-", state)
    for klass in @dom.attr('class').split(' ')
      @dom.removeClass(klass) if /^state-/.test(klass)
    @dom.addClass(targetKlass)
    $('.state', @dom).text(state)
    @syncDialogState()

  setStatus: (@status) ->
    targetKlass = statusOrStateToClass("status-", status)
    for klass in @dom.attr('class').split(' ')
      @dom.removeClass(klass) if /^status-/.test(klass)
    @dom.addClass(targetKlass)
    $('.status', @dom).text(status)
    @syncDialogStatus()

  setUsername: (@username) ->
  setExtension: (@extension) ->

  calltap: ->
    p "Tapping #{@name} for #{store.agent}"
    store.ws.say(
      method: 'calltap',
      agent: @name,
      tapper: store.agent,
    )

  # do time ticking here
  tick: ->
    for uuid, call of @calls
      call.tick()

  show: ->
    @dom.show()

  hide: ->
    @dom.hide()

  doubleClicked: ->
    @dialog = store.protoAgentDialog.clone(true)
    @dialog.attr('id', "dialog-#{@name}")
    @dialog.dialog(
      autoOpen: true,
      title: "#{@extension} #{@username}",
      modal: false,
      open: (event, ui) =>
        @syncDialog()
        for uuid, call of @calls
          call.renderInDialog()
        $('.calltap', @dialog).click (event) =>
          @calltap()
          false
        $('.calls .uuid', @dialog).click (event) =>
          @calls[$(event.target).text()].calltap()
          false
        $('.status a', @dialog).click (event) =>
          store.ws.say(
            method: 'status_of',
            agent: @name,
            status: statusOrStateToClass('', $(event.target).text()).replace(/-/g, '_')
          )
          false
        $('.state a', @dialog).click (event) =>
          store.ws.say(
            method: 'state_of',
            agent: @name,
            state: $(event.target).attr('class'),
          )
          false
      close: (event, ui) =>
        @dialog.remove()
    )


  syncDialog: ->
    @syncDialogStatus()
    @syncDialogState()

  syncDialogStatus: ->
    targetKlass = statusOrStateToClass("", @status)
    $(".status a", @dialog).removeClass('active')
    $(".status a.#{targetKlass}", @dialog).addClass('active')

  syncDialogState: ->
    targetKlass = @state
    $(".state a", @dialog).removeClass('active')
    $(".state a.#{targetKlass}", @dialog).addClass('active')

$ ->
  store.server = $('#server').text()
  store.agent = $('#agent_name').text()
  store.ws = new Socket(new Controller())

  store.protoCall = $('#proto-call').detach()
  store.protoAgent = $('#proto-agent').detach()
  store.protoAgentDialog = $('#proto-agent-dialog').detach()

  $('#nav-queues a').live 'click', (event) =>
    store.ws.say(method: 'agents_of', queue: $(event.target).text())

  $('#show-all-agents').live 'click', (event) =>
    agent.show() for name, agent of store.agents

  $('.agent').live 'dblclick', (event) =>
    agent_id = $(event.target).closest('.agent').attr('id').replace(/^agent-/, "")
    agent = store.agents[agent_id]
    agent.doubleClicked()

  setInterval =>
    agent.tick() for name, agent of store.agents
  , 1000
