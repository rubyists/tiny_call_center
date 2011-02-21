(function() {
  var Agent, Call, Controller, Socket, divmod, formatInterval, formatPhoneNumber, p, queueToClass, searchToQuery, statusOrStateToClass, store;
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
  p = function() {
    var _ref;
    return (_ref = window.console) != null ? typeof _ref.debug == "function" ? _ref.debug(arguments) : void 0 : void 0;
  };
  store = {
    agents: {},
    searches: {},
    stateMapping: {
      Idle: 'Wrap Up',
      Waiting: 'Ready'
    }
  };
  statusOrStateToClass = function(prefix, str) {
    return prefix + str.toLowerCase().replace(/\W+/g, "-").replace(/^-+|-+$/g, "");
  };
  queueToClass = function(queue) {
    return queue.toLowerCase().replace(/\W+/g, '_').replace(/^_+|_+$/g, "");
  };
  divmod = function(num1, num2) {
    return [num1 / num2, num1 % num2];
  };
  formatInterval = function(start) {
    var hours, minutes, rest, seconds, total, _ref, _ref2;
    total = parseInt((Date.now() - start) / 1000, 10);
    _ref = divmod(total, 60 * 60), hours = _ref[0], rest = _ref[1];
    _ref2 = divmod(rest, 60), minutes = _ref2[0], seconds = _ref2[1];
    return sprintf("%02d:%02d:%02d", hours, minutes, seconds);
  };
  formatPhoneNumber = function(number) {
    var md;
    if (number == null) {
      return number;
    }
    md = number.match(/^(\d{3})(\d{3})(\d{4})/);
    if (md == null) {
      return number;
    }
    return "(" + md[1] + ")-" + md[2] + "-" + md[3];
  };
  searchToQuery = function(raw) {
    var part, query, _i, _len, _ref;
    if (/^[,\s]*$/.test(raw)) {
      $('#agents').isotope({
        filter: '*'
      });
      return false;
    }
    query = [];
    _ref = raw.split(/\s*,\s*/g);
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      part = _ref[_i];
      part = part.replace(/'/, '');
      query.push(":contains('" + part + "')");
    }
    return query.join(", ");
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
        return this.controller.dispatch(data);
      }, this);
      this.ws.onclose = __bind(function() {
        p("Closing WebSocket");
        if (this.reconnectInterval) {
          return;
        }
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
      var a, li, list, queue, sorted, unsorted, _i, _j, _len, _len2, _results;
      list = $('#nav-queues');
      list.html('');
      unsorted = [];
      for (_i = 0, _len = queues.length; _i < _len; _i++) {
        queue = queues[_i];
        unsorted.push(queue);
      }
      sorted = unsorted.sort(function(a, b) {
        return a.name > b.name;
      });
      _results = [];
      for (_j = 0, _len2 = sorted.length; _j < _len2; _j++) {
        queue = sorted[_j];
        li = $('<li>');
        a = $('<a>', {
          href: '#'
        }).text(queue.name);
        li.append(a);
        _results.push(list.append(li));
      }
      return _results;
    };
    Controller.prototype.got_agent_list = function(agents) {
      var agent, rawAgent, _i, _len, _results;
      p(agents);
      _results = [];
      for (_i = 0, _len = agents.length; _i < _len; _i++) {
        rawAgent = agents[_i];
        agent = store.agents[rawAgent.name] || new Agent(rawAgent.name);
        _results.push(agent.fillFromAgent(rawAgent));
      }
      return _results;
    };
    Controller.prototype.got_agents_of = function(queue, tiers) {
      var agent, tier, _i, _len;
      for (_i = 0, _len = tiers.length; _i < _len; _i++) {
        tier = tiers[_i];
        agent = store.agents[tier.agent] || new Agent(tier.agent);
        agent.fillFromTier(tier);
      }
      return $('#agents').isotope({
        filter: "." + (queueToClass(queue))
      });
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
      this.klass = "call-" + this.uuid;
      this.createDOM();
      this.renderInAgent();
      this.renderInDialog();
      this.setTimer(new Date(Date.parse(msg.call_created)));
      this.agent.calls[this.uuid] = this;
    }
    Call.prototype.createDOM = function() {
      this.dom = store.protoCall.clone();
      this.dom.attr('id', '');
      this.dom.attr('class', "" + this.klass + " call");
      $('.cid-number', this.dom).text(formatPhoneNumber(this.remoteLeg.cid_number));
      $('.cid-name', this.dom).text(this.remoteLeg.cid_name);
      $('.destination', this.dom).text(formatPhoneNumber(this.remoteLeg.destination));
      $('.queue-name', this.dom).text(this.localLeg.queue);
      $('.uuid', this.dom).text(this.localLeg.uuid);
      $('.channel', this.dom).text(this.localLeg.channel);
      return this.dialogDOM = this.dom.clone(true);
    };
    Call.prototype.setTimer = function(startingTime) {
      this.startingTime = startingTime;
      return this.timer = setInterval(__bind(function() {
        if (this.dom) {
          $('.time-of-call-start', this.dom).text(formatInterval(this.startingTime));
        }
        if (this.dialogDOM) {
          return $('.time-of-call-start', this.dialogDOM).text(formatInterval(this.startingTime));
        }
      }, this), 1000);
    };
    Call.prototype.hangup = function(msg) {
      this.agent.startingTime = new Date(Date.now());
      delete this.agent.calls[this.uuid];
      clearInterval(this.timer);
      this.dom.slideUp("normal", function() {
        return $(this).remove();
      });
      return this.dialogDOM.remove();
    };
    Call.prototype.renderInAgent = function() {
      return $('.calls', this.agent.dom).append(this.dom);
    };
    Call.prototype.renderInDialog = function() {
      if (this.agent.dialog != null) {
        return $('.calls', this.agent.dialog).append(this.dialogDOM);
      }
    };
    Call.prototype.calltap = function() {
      p("tapping " + this.agent.name + ": " + this.agent.extension + " <=> " + this.remoteLeg.cid_number + " (" + this.localLeg.uuid + ") by " + store.agent);
      return store.ws.say({
        method: 'calltap_too',
        tapper: store.agent,
        name: this.agent.name,
        extension: this.agent.extension,
        uuid: this.localLeg.uuid,
        phoneNumber: this.remoteLeg.cid_number
      });
    };
    return Call;
  })();
  Agent = (function() {
    function Agent(name) {
      this.name = name;
      this.calls = {};
      this.createDOM();
      store.agents[this.name] = this;
    }
    Agent.prototype.createDOM = function() {
      this.dom = store.protoAgent.clone();
      this.dom.attr('id', "agent-" + this.name);
      $('.name', this.dom).text(this.name);
      return $('#agents').isotope('insert', this.dom);
    };
    Agent.prototype.setTimer = function(startingTime) {
      this.startingTime = startingTime;
      $('.time-since-status-change', this.dom).text(formatInterval(this.startingTime));
      $('#agents').isotope('updateSortData', this.dom);
      return this.timer = setInterval(__bind(function() {
        return $('.time-since-status-change', this.dom).text(formatInterval(this.startingTime));
      }, this), 1000);
    };
    Agent.prototype.fillFromAgent = function(d) {
      var msg;
      this.setName(d.name);
      this.setState(d.state);
      this.setStatus(d.status);
      this.setUsername(d.username);
      this.setExtension(d.extension);
      this.busy_delay_time = d.busy_delay_time;
      this.class_answered = d.class_answered;
      this.contact = d.contact;
      this.last_call_time = new Date(Date.parse(d.last_call_time));
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
      this.wrap_up_time = d.wrap_up_time;
      if (this.last_call_time) {
        this.setTimer(this.last_call_time);
      }
      if (d.call_created) {
        msg = {
          call_created: d.call_created,
          left: {
            cid_number: d.caller_cid_num,
            cid_name: d.caller_cid_name,
            destination: d.caller_dest_num,
            channel: d.contact,
            uuid: d.uuid
          },
          right: {
            cid_number: d.callee_cid_num,
            cid_name: d.callee_cid_name,
            channel: d.contact,
            uuid: d.uuid
          }
        };
        return this.got_call_start(msg);
      }
    };
    Agent.prototype.fillFromTier = function(d) {
      this.setName(d.agent);
      this.setState(d.state);
      this.level = d.level;
      this.position = d.position;
      return this.setQueue(d.queue);
    };
    Agent.prototype.got_call_start = function(msg) {
      var extMatch, left, leftMatch, right, rightMatch, _ref, _ref2, _ref3, _ref4, _ref5;
      extMatch = /(?:^|\/)(?:sip:)?(\d+)[@-]/;
      _ref = [msg.left, msg.right], left = _ref[0], right = _ref[1];
      leftMatch = (_ref2 = left.channel) != null ? typeof _ref2.match == "function" ? (_ref3 = _ref2.match(extMatch)) != null ? _ref3[1] : void 0 : void 0 : void 0;
      rightMatch = (_ref4 = right.channel) != null ? typeof _ref4.match == "function" ? (_ref5 = _ref4.match(extMatch)) != null ? _ref5[1] : void 0 : void 0 : void 0;
      if (this.extension === leftMatch) {
        return this.makeCall(left, right, msg);
      } else if (this.extension === rightMatch) {
        return this.makeCall(right, left, msg);
      } else if (right.destination === rightMatch) {
        return this.makeCall(right, left, msg);
      } else if (left.destination === leftMatch) {
        return this.makeCall(left, right, msg);
      } else if (left.cid_number === leftMatch) {
        return this.makeCall(left, right, msg);
      } else if (right.cid_number === rightMatch) {
        return this.makeCall(right, left, msg);
      }
    };
    Agent.prototype.makeCall = function(left, right, msg) {
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
            return;
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
    Agent.prototype.setQueue = function(queue) {
      this.queue = queue;
      $('.queue', this.dom).text(this.queue);
      return this.dom.addClass(queueToClass(queue));
    };
    Agent.prototype.setName = function(name) {
      this.name = name;
      return this.dom.attr('id', "agent-" + name);
    };
    Agent.prototype.setState = function(state) {
      var alias, klass, targetKlass, _i, _len, _ref;
      this.state = state;
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
      $('.state', this.dom).text(state);
      $('#agents').isotope('updateSortData', this.dom);
      return this.syncDialogState();
    };
    Agent.prototype.setStatus = function(status) {
      var klass, targetKlass, _i, _len, _ref;
      this.status = status;
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
      $('#agents').isotope('updateSortData', this.dom);
      return this.syncDialogStatus();
    };
    Agent.prototype.setUsername = function(username) {
      this.username = username;
      $('.username', this.dom).text(this.username);
      return $('#agents').isotope('updateSortData', this.dom);
    };
    Agent.prototype.setExtension = function(extension) {
      this.extension = extension;
      $('.extension', this.dom).text(this.extension);
      return $('#agents').isotope('updateSortData', this.dom);
    };
    Agent.prototype.calltap = function() {
      p("Tapping " + this.name + " for " + store.agent);
      return store.ws.say({
        method: 'calltap',
        agent: this.name,
        tapper: store.agent
      });
    };
    Agent.prototype.show = function() {
      return this.dom.show();
    };
    Agent.prototype.hide = function() {
      return this.dom.hide();
    };
    Agent.prototype.doubleClicked = function() {
      this.dialog = store.protoAgentDialog.clone(true);
      this.dialog.attr('id', "dialog-" + this.name);
      return this.dialog.dialog({
        autoOpen: true,
        title: "" + this.extension + " " + this.username,
        modal: false,
        width: 800,
        open: __bind(function(event, ui) {
          var call, uuid, _ref;
          this.syncDialog();
          _ref = this.calls;
          for (uuid in _ref) {
            call = _ref[uuid];
            call.renderInDialog();
          }
          $('.dialog-tabs .tab-title', this.dialog).each(__bind(function(i, t) {
            return $(t).attr('href', "#dialog-tab-" + this.name + "-" + i);
          }, this));
          $('.dialog-tabs .tab-content', this.dialog).each(__bind(function(i, t) {
            return $(t).attr('id', "dialog-tab-" + this.name + "-" + i);
          }, this));
          $('.dialog-tabs', this.dialog).tabs({
            idPrefix: "dialog-tab-" + this.name,
            show: __bind(function(showEvent, showUi) {
              return this.handleShowTab(showEvent, showUi);
            }, this)
          });
          $('.calltap', this.dialog).click(__bind(function(event) {
            this.calltap();
            return false;
          }, this));
          $('.calls .calltap-uuid', this.dialog).click(__bind(function(event) {
            var realCall;
            call = $(event.target).closest('.call');
            uuid = $('.uuid', call).text();
            realCall = this.calls[uuid];
            realCall.calltap();
            return false;
          }, this));
          $('.status a', this.dialog).click(__bind(function(event) {
            store.ws.say({
              method: 'status_of',
              agent: this.name,
              status: statusOrStateToClass('', $(event.target).text()).replace(/-/g, '_')
            });
            return false;
          }, this));
          return $('.state a', this.dialog).click(__bind(function(event) {
            store.ws.say({
              method: 'state_of',
              agent: this.name,
              state: $(event.target).attr('class')
            });
            return false;
          }, this));
        }, this),
        close: __bind(function(event, ui) {
          return this.dialog.remove();
        }, this)
      });
    };
    Agent.prototype.handleShowTab = function(event, ui) {
      var href, tab;
      href = $(ui.tab).attr('href');
      tab = $(href);
      if (tab.hasClass('tab-status-log')) {
        store.ws.say({
          method: 'agent_status_history',
          agent: this.name
        });
      }
      if (tab.hasClass('tab-state-log')) {
        return store.ws.say({
          method: 'agent_state_history',
          agent: this.name
        });
      }
    };
    Agent.prototype.got_agent_status_history = function(msg) {
      var created_at, row, _i, _len, _ref, _results;
      $('.tab-status-log tbody', this.dialog).html('');
      _ref = msg.history;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        row = _ref[_i];
        created_at = new Date(Date.parse(row.created_at));
        _results.push($('.tab-status-log tbody', this.dialog).append($('<tr>').html("<td>" + row.new_status + "</td><td>" + created_at + "</td>")));
      }
      return _results;
    };
    Agent.prototype.got_agent_state_history = function(msg) {
      var created_at, row, _i, _len, _ref, _results;
      $('.tab-state-log tbody', this.dialog).html('');
      _ref = msg.history;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        row = _ref[_i];
        created_at = new Date(Date.parse(row.created_at));
        _results.push($('.tab-state-log tbody', this.dialog).append($('<tr>').html("<td>" + row.new_state + "</td><td>" + created_at + "</td>")));
      }
      return _results;
    };
    Agent.prototype.syncDialog = function() {
      this.syncDialogStatus();
      return this.syncDialogState();
    };
    Agent.prototype.syncDialogStatus = function() {
      var targetKlass;
      targetKlass = statusOrStateToClass("", this.status);
      $(".status a", this.dialog).removeClass('active');
      return $(".status a." + targetKlass, this.dialog).addClass('active');
    };
    Agent.prototype.syncDialogState = function() {
      var targetKlass;
      targetKlass = this.state;
      $(".state a", this.dialog).removeClass('active');
      return $(".state a." + targetKlass, this.dialog).addClass('active');
    };
    return Agent;
  })();
  $(function() {
    store.server = $('#server').text();
    if (store.server === '') {
      store.server = "ws://" + location.hostname + ":8081/websocket";
    }
    store.agent = $('#agent_name').text();
    store.protoCall = $('#proto-call').detach();
    store.protoAgent = $('#proto-agent').detach();
    store.protoAgentDialog = $('#proto-agent-dialog').detach();
    $('#nav-queues a').live('click', __bind(function(event) {
      var queue;
      queue = $(event.target).text();
      store.ws.say({
        method: 'agents_of',
        queue: queue
      });
      return false;
    }, this));
    $('#show-all-agents').live('click', function(event) {
      $('#agents').isotope({
        filter: '*'
      });
      return false;
    });
    $('#search').keyup(__bind(function(event) {
      var query, raw;
      if (event.keyCode === 13) {
        event.preventDefault();
      }
      raw = $(event.target).val();
      if (query = searchToQuery(raw)) {
        $('#agents').isotope({
          filter: query
        });
      }
      return false;
    }, this));
    $('#save-search').click(__bind(function(event) {
      var query, raw;
      raw = $('#search').val();
      if (query = searchToQuery(raw)) {
        if (!store.searches[raw]) {
          store.searches[raw] = query;
          return $('#prev-search').append($('<option>', {
            value: query
          }).text(raw));
        }
      }
    }, this));
    $('#prev-search').change(__bind(function(event) {
      var query;
      query = $(event.target).val();
      return $('#agents').isotope({
        filter: query
      });
    }, this));
    $('.sorter').click(function(event) {
      var sorter;
      sorter = $(event.target).attr('id').replace(/^sort-/, "");
      $('#agents').isotope({
        sortBy: sorter
      });
      return false;
    });
    $('.agent').live('dblclick', __bind(function(event) {
      var agent, agent_id;
      agent_id = $(event.target).closest('.agent').attr('id').replace(/^agent-/, "");
      agent = store.agents[agent_id];
      agent.doubleClicked();
      return false;
    }, this));
    $('#agents').isotope({
      itemSelector: '.agent',
      layoutMode: 'fitRows',
      getSortData: {
        username: function(e) {
          return e.find('.username').text();
        },
        extension: function(e) {
          return e.find('.extension').text();
        },
        status: function(e) {
          var extension, order, s;
          s = e.find('.status').text();
          order = (function() {
            switch (s) {
              case 'Available':
                return 0.7;
              case 'Available (On Demand)':
                return 0.8;
              case 'On Break':
                return 0.9;
              case 'Logged Out':
                return 1.0;
            }
          })();
          extension = e.find('.extension').text();
          return parseFloat("" + order + extension);
        },
        idle: function(e) {
          var min, sec, _ref;
          _ref = e.find('.time-since-status-change').text().split(':'), min = _ref[0], sec = _ref[1];
          return (parseInt(min, 10) * 60) + parseInt(sec, 10);
        }
      },
      sortBy: 'status'
    });
    return store.ws = new Socket(new Controller());
  });
}).call(this);
