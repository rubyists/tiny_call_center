(function() {
  var Agent, Call, Controller, Socket, p, statusOrStateToClass, store;
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
  p = function() {
    var _ref;
    return (_ref = window.console) != null ? typeof _ref.debug === "function" ? _ref.debug(arguments) : void 0 : void 0;
  };
  store = {
    agents: {},
    stateMapping: {
      Idle: 'Wrap Up',
      Waiting: 'Ready'
    }
  };
  statusOrStateToClass = function(prefix, str) {
    return prefix + str.toLowerCase().replace(/\W+/g, "-").replace(/^-+|-+$/g, "");
  };
  Socket = (function() {
    function Socket(controller) {
      this.controller = controller;
      this.connect();
    }
    Socket.prototype.connect = function() {
      this.ws = new WebSocket(store.server);
      this.ws.onopen = __bind(function() {
        if (this.reconnectInterval) {
          clearInterval(this.reconnectInterval);
        }
        return this.say({
          method: 'subscribe',
          agent: store.agent
        });
      }, this);
      this.ws.onmessage = __bind(function(message) {
        var data;
        data = JSON.parse(message.data);
        p("onMessage", data);
        return this.controller.dispatch(data);
      }, this);
      this.ws.onclose = __bind(function() {
        p("Closing WebSocket");
        return this.reconnectInterval = setInterval(__bind(function() {
          p("Reconnect");
          return this.connect();
        }, this), 1000);
      }, this);
      return this.ws.onerror = __bind(function(error) {
        return p("WebSocket Error:", error);
      }, this);
    };
    Socket.prototype.say = function(obj) {
      p("Socket.send", obj);
      return this.ws.send(JSON.stringify(obj));
    };
    return Socket;
  })();
  Controller = (function() {
    function Controller() {}
    Controller.prototype.dispatch = function(msg) {
      var action, method;
      if (method = msg.method) {
        return this["got_" + method].apply(this, msg.args);
      } else if (action = msg.tiny_action) {
        return store.agents[msg.cc_agent]["got_" + action](msg);
      }
    };
    Controller.prototype.got_queues = function(queues) {
      var a, li, queue, _i, _len, _results;
      $('#nav-queues').html('');
      _results = [];
      for (_i = 0, _len = queues.length; _i < _len; _i++) {
        queue = queues[_i];
        li = $('<li>');
        a = $('<a>', {
          href: '#'
        }).text(queue.name);
        li.append(a);
        _results.push($('#nav-queues').append(li));
      }
      return _results;
    };
    Controller.prototype.got_agent_list = function(agents) {
      var agent, rawAgent, _i, _len, _results;
      _results = [];
      for (_i = 0, _len = agents.length; _i < _len; _i++) {
        rawAgent = agents[_i];
        agent = store.agents[rawAgent.name] || new Agent(rawAgent.name);
        _results.push(agent.fillFromAgent(rawAgent));
      }
      return _results;
    };
    Controller.prototype.got_agents_of = function(queue, tiers) {
      var agent, name, tier, _i, _len, _ref, _results;
      _ref = store.agents;
      for (name in _ref) {
        agent = _ref[name];
        agent.hide();
      }
      _results = [];
      for (_i = 0, _len = tiers.length; _i < _len; _i++) {
        tier = tiers[_i];
        agent = store.agents[tier.agent] || new Agent(tier.agent);
        agent.fillFromTier(tier);
        _results.push(agent.show());
      }
      return _results;
    };
    Controller.prototype.got_call_start = function(msg) {
      return store.agents[msg.cc_agent].got_call_start(msg);
    };
    Controller.prototype.got_channel_hangup = function(msg) {
      return store.agents[msg.cc_agent].got_channel_hangup(msg);
    };
    return Controller;
  })();
  Call = (function() {
    function Call(agent, localLeg, remoteLeg, msg) {
      this.agent = agent;
      this.localLeg = localLeg;
      this.remoteLeg = remoteLeg;
      this.uuid = localLeg.uuid;
      this.createDOM();
      this.agent.calls[this.uuid] = this;
    }
    Call.prototype.createDOM = function() {
      this.dom = store.protoCall.clone();
      this.dom.attr('id', "call-" + this.uuid);
      $('.calls', this.agent.dom).append(this.dom);
      $('.state', this.dom).text('On A Call');
      $('.cid-number', this.dom).text(this.remoteLeg.cid_number);
      $('.cid-name', this.dom).text(this.remoteLeg.cid_name);
      $('.destination-number', this.dom).text(this.remoteLeg.destination_number);
      $('.queue-name', this.dom).text(this.localLeg.queue);
      $('.uuid', this.dom).text(this.localLeg.uuid);
      $('.channel', this.dom).text(this.localLeg.channel);
      $('.calls', this.agent.dom).append(this.dom);
      return this.dom.show();
    };
    Call.prototype.hangup = function(msg) {
      delete this.agent.calls[this.uuid];
      this.dom.remove();
      return this.dom.slideUp("normal", function() {
        return $(this).remove();
      });
    };
    return Call;
  })();
  Agent = (function() {
    function Agent(name) {
      this.name = name;
      this.meta = {};
      this.calls = {};
      store.agents[this.name] = this;
      this.createDOM();
    }
    Agent.prototype.createDOM = function() {
      this.dom = store.protoAgent.clone();
      this.dom.attr('id', "agent-" + this.name);
      $('.name', this.dom).text(this.name);
      $('#agents').append(this.dom);
      return this.dom.show();
    };
    Agent.prototype.fillFromAgent = function(d) {
      this.setName(d.name);
      this.setState(d.state);
      this.setStatus(d.status);
      this.setUsername(d.username);
      this.setExtension(d.extension);
      this.busy_delay_time = d.busy_delay_time;
      this.class_answered = d.class_answered;
      this.contact = d.contact;
      this.last_bridge_end = new Date(Date.parse(d.last_bridge_end));
      this.last_bridge_start = new Date(Date.parse(d.last_bridge_start));
      this.last_offered_call = new Date(Date.parse(d.last_offered_call));
      this.last_status_change = new Date(Date.parse(d.last_status_change));
      this.max_no_answer = d.max_no_answer;
      this.no_answer_count = d.no_answer_count;
      this.ready_time = d.ready_time;
      this.reject_delay_time = d.reject_delay_time;
      this.system = d.system;
      this.talk_time = d.talk_time;
      this.type = d.type;
      this.uuid = d.uuid;
      return this.wrap_up_time = d.wrap_up_time;
    };
    Agent.prototype.fillFromTier = function(d) {
      this.setName(d.agent);
      this.setState(d.state);
      this.level = d.level;
      this.position = d.position;
      return this.queue = d.queue;
    };
    Agent.prototype.got_call_start = function(msg) {
      var extMatch, leftMatch, rightMatch, _ref, _ref2, _ref3, _ref4;
      extMatch = /(?:^|\/)(\d+)[@-]/;
      leftMatch = (_ref = msg.left.channel) != null ? typeof _ref.match === "function" ? (_ref2 = _ref.match(extMatch)) != null ? _ref2[1] : void 0 : void 0 : void 0;
      rightMatch = (_ref3 = msg.right.channel) != null ? typeof _ref3.match === "function" ? (_ref4 = _ref3.match(extMatch)) != null ? _ref4[1] : void 0 : void 0 : void 0;
      if (this.extension === leftMatch) {
        return this.makeCall(msg.left, msg.right, msg);
      } else if (this.extension === rightMatch) {
        return this.makeCall(msg.right, msg.left, msg);
      } else if (msg.right.destination === rightMatch) {
        return this.makeCall(msg.right, msg.left, msg);
      } else if (msg.left.destination === leftMatch) {
        return this.makeCall(msg.left, msg.right, msg);
      } else if (msg.left.cid_number === leftMatch) {
        return this.makeCall(msg.left, msg.right, msg);
      } else if (msg.right.cid_number === rightMatch) {
        return this.makeCall(msg.right, msg.left, msg);
      }
    };
    Agent.prototype.makeCall = function(left, right, msg) {
      p(["makeCall", this, left, right, msg]);
      if (!this.calls[left.uuid]) {
        return new Call(this, left, right, msg);
      }
    };
    Agent.prototype.got_channel_hangup = function(msg) {
      var call, key, value, _results;
      _results = [];
      for (key in msg) {
        value = msg[key];
        if (/unique|uuid/.test(key)) {
          if (call = this.calls[value]) {
            call.hangup(msg);
            return void 0;
          }
        }
      }
      return _results;
    };
    Agent.prototype.got_status_change = function(msg) {
      return this.setStatus(msg.cc_agent_status);
    };
    Agent.prototype.got_state_change = function(msg) {
      return this.setState(msg.cc_agent_state);
    };
    Agent.prototype.setName = function(name) {
      this.name = name;
      this.dom.attr('id', "agent-" + name);
      return $('.name', this.dom).text(name);
    };
    Agent.prototype.setState = function(state) {
      var alias, klass, targetKlass, _i, _len, _ref;
      this.state = state;
      p(["setState", state]);
      if (!(alias = store.stateMapping[state])) {
        return;
      }
      state = alias;
      targetKlass = statusOrStateToClass("state-", state);
      _ref = this.dom.attr('class').split(' ');
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        klass = _ref[_i];
        if (/^state-/.test(klass)) {
          this.dom.removeClass(klass);
        }
      }
      this.dom.addClass(targetKlass);
      return $('.state', this.dom).text(state);
    };
    Agent.prototype.setStatus = function(status) {
      var klass, targetKlass, _i, _len, _ref;
      this.status = status;
      p(["setStatus", status]);
      targetKlass = statusOrStateToClass("status-", status);
      _ref = this.dom.attr('class').split(' ');
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        klass = _ref[_i];
        if (/^status-/.test(klass)) {
          this.dom.removeClass(klass);
        }
      }
      this.dom.addClass(targetKlass);
      $('.status', this.dom).text(status);
      return this.syncDialogStatus();
    };
    Agent.prototype.setUsername = function(username) {
      this.username = username;
    };
    Agent.prototype.setExtension = function(extension) {
      this.extension = extension;
    };
    Agent.prototype.tick = function() {};
    Agent.prototype.show = function() {
      return this.dom.show();
    };
    Agent.prototype.hide = function() {
      return this.dom.hide();
    };
    Agent.prototype.doubleClicked = function() {
      var dialog;
      dialog = store.protoAgentDialog.clone(true);
      dialog.attr('id', "dialog-" + this.name);
      return dialog.dialog({
        autoOpen: true,
        title: "" + this.extension + " " + this.username,
        modal: false,
        open: __bind(function(event, ui) {
          this.syncDialogStatus();
          return $('.status a', dialog).click(__bind(function(event) {
            return store.ws.say({
              method: 'status_of',
              agent: this.name,
              status: statusOrStateToClass('', $(event.target).text()).replace(/-/g, '_')
            });
          }, this));
        }, this),
        close: __bind(function(event, ui) {
          return dialog.remove();
        }, this)
      });
    };
    Agent.prototype.syncDialogStatus = function() {
      var targetKlass;
      targetKlass = statusOrStateToClass("", this.status);
      p(targetKlass);
      p($("#dialog-" + this.name + " .status a"));
      $("#dialog-" + this.name + " .status a").removeClass('active');
      return $("#dialog-" + this.name + " .status a." + targetKlass).addClass('active');
    };
    return Agent;
  })();
  $(function() {
    store.server = $('#server').text();
    store.agent = $('#agent_name').text();
    store.ws = new Socket(new Controller());
    store.protoCall = $('#proto-call').detach();
    store.protoAgent = $('#proto-agent').detach();
    store.protoAgentDialog = $('#proto-agent-dialog').detach();
    $('#nav-queues a').live('click', __bind(function(event) {
      return store.ws.say({
        method: 'agents_of',
        queue: $(event.target).text()
      });
    }, this));
    $('#show-all-agents').live('click', __bind(function(event) {
      var agent, name, _ref, _results;
      _ref = store.agents;
      _results = [];
      for (name in _ref) {
        agent = _ref[name];
        _results.push(agent.show());
      }
      return _results;
    }, this));
    $('.agent').live('dblclick', __bind(function(event) {
      var agent, agent_id;
      agent_id = $(event.target).attr('id').replace(/^agent-/, "");
      agent = store.agents[agent_id];
      return agent.doubleClicked();
    }, this));
    return setInterval(__bind(function() {
      var agent, name, _ref, _results;
      _ref = store.agents;
      _results = [];
      for (name in _ref) {
        agent = _ref[name];
        _results.push(agent.tick());
      }
      return _results;
    }, this), 1000);
  });
}).call(this);
