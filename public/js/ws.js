(function() {
  var Call, agentStateChange, agentStatusChange, agentWantsStateChange, agentWantsStatusChange, currentState, currentStatus, keyCodes, onClose, onError, onMessage, onOpen, p, setupWs, showError, store;
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
  store = {
    calls: {},
    send: function(obj) {
      return this.ws.send(JSON.stringify(obj));
    }
  };
  keyCodes = {
    F1: 112,
    F2: 113,
    F3: 114,
    F4: 115,
    F5: 116,
    F6: 117,
    F7: 118,
    F8: 119,
    F9: 120,
    F10: 121,
    F11: 122,
    F12: 123
  };
  p = function(msg) {
    var _ref;
    return (_ref = window.console) != null ? typeof _ref.debug === "function" ? _ref.debug(msg) : void 0 : void 0;
  };
  showError = function(msg) {
    return $('#error').text(msg);
  };
  Call = (function() {
    function Call(local_leg, remote_leg, msg) {
      this.uuid = local_leg.uuid;
      this.local_leg = local_leg;
      this.remote_leg = remote_leg;
      store.calls[this.uuid] = this;
      this.prepareDOM();
      this.talkingStart(new Date(Date.parse(msg.call_created)));
    }
    Call.prototype.prepareDOM = function() {
      this.sel = store.call_template.clone();
      this.sel.attr('id', '');
      $('#calls').append(this.sel);
      this.dom = {
        state: $('.state', this.sel),
        cidNumber: $('.cid-number', this.sel),
        cidName: $('.cid-name', this.sel),
        answered: $('.answered', this.sel),
        called: $('.called', this.sel),
        destinationNumber: $('.destination-number', this.sel),
        queueName: $('.queue-name', this.sel),
        uuid: $('.uuid', this.sel),
        channel: $('.channel', this.sel)
      };
      this.dom.state.text('On A Call');
      this.dom.cidNumber.text(this.remote_leg.cid_number);
      this.dom.cidName.text(this.remote_leg.cid_name);
      this.dom.destinationNumber.text(this.remote_leg.destination_number);
      this.dom.queueName.text(this.local_leg.queue);
      this.dom.uuid.text(this.local_leg.uuid);
      return this.dom.channel.text(this.local_leg.channel);
    };
    Call.prototype.call_start = function(msg) {
      return p("call_start");
    };
    Call.prototype.initial_status = function(msg) {
      switch (store.agent_ext) {
        case msg.caller_cid_num:
          this.dom.cidNumber.text(msg.callee_cid_num);
          return this.talkingStart(new Date(Date.parse(msg.call_created)));
        case msg.callee_cid_num:
          this.dom.cidNumber.text(msg.caller_cid_num);
          this.dom.cidName.text(msg.caller_cid_name);
          return this.talkingStart(new Date(Date.parse(msg.call_created)));
      }
    };
    Call.prototype['bridge-agent-start'] = function(msg) {
      this.dom.cidName.text(msg.cc_caller_cid_name);
      this.dom.cidNumber.text(msg.cc_caller_cid_number);
      return this.talkingStart(new Date(Date.now()));
    };
    Call.prototype['bridge-agent-end'] = function(msg) {
      this.dom.cidName.text('');
      this.dom.cidNumber.text('');
      return this.talkingEnd();
    };
    Call.prototype.channel_hangup = function(msg) {
      return this.talkingEnd();
    };
    Call.prototype.channel_answer = function(msg) {
      if (msg.caller_destination_number === store.agent_ext) {
        return this.answeredCall('Inbound Call', msg.caller_caller_id_name, msg.caller_caller_id_number, msg.channel_call_uuid || msg.unique_id);
      } else if (msg.caller_caller_id_number === store.agent_ext) {
        return this.answeredCall('Outbound Call', msg.caller_destination_number, msg.caller_callee_id_number, msg.channel_call_uuid || msg.unique_id);
      }
    };
    Call.prototype.answeredCall = function(cidName, cidNumber, uuid) {
      this.dom.cidNumber.text(cidNumber);
      if (cidName != null) {
        this.dom.cidName.text(cidName);
      }
      return this.talkingStart(new Date(Date.now()));
    };
    Call.prototype.talkingStart = function(answeredTime) {
      if (this.answered != null) {
        return;
      }
      this.answered = answeredTime || new Date(Date.now());
      return this.answeredInterval = setInterval(__bind(function() {
        var talkTime;
        talkTime = parseInt((Date.now() - this.answered) / 1000, 10);
        return this.dom.answered.text("" + (this.answered.toLocaleTimeString()) + " (" + talkTime + "s)");
      }, this), 1000);
    };
    Call.prototype.talkingEnd = function() {
      clearInterval(this.answeredInterval);
      delete store.calls[this.uuid];
      return this.askDisposition();
    };
    Call.prototype.askDisposition = function() {
      $('#disposition button').one('click', __bind(function(event) {
        var jbutton;
        p(event);
        jbutton = $(event.target);
        store.send({
          method: 'disposition',
          code: jbutton.attr('id').split('-')[1],
          desc: jbutton.attr('label'),
          left: this.local_leg,
          right: this.remote_leg
        });
        this.sel.remove();
        $('#disposition').hide();
        return false;
      }, this));
      return $('#disposition').show();
    };
    return Call;
  })();
  currentStatus = function(tag) {
    $('#status a').attr('class', 'inactive');
    return tag.attr("class", "active");
  };
  agentStatusChange = function(msg) {
    switch (msg.cc_agent_status.toLowerCase()) {
      case 'available':
      case 'available (on demand)':
        return currentStatus($('#available'));
      case 'on break':
        return currentStatus($('#on_break'));
      case 'logged out':
        return currentStatus($('#logged_out'));
    }
  };
  currentState = function(tag) {
    $('#state a').attr('class', 'inactive');
    return tag.attr('class', 'active');
  };
  agentStateChange = function(msg) {
    return currentState($("#" + msg.cc_agent_state));
  };
  onMessage = function(event) {
    var call, extMatch, key, makeCall, msg, value, _name, _ref, _ref10, _ref11, _ref12, _ref2, _ref3, _ref4, _ref5, _ref6, _ref7, _ref8, _ref9, _results;
    msg = JSON.parse(event.data);
    p(msg);
    switch (msg.tiny_action) {
      case 'status_change':
        return agentStatusChange(msg);
      case 'state_change':
        return agentStateChange(msg);
      case 'call_start':
        extMatch = /(?:^|\/)(\d+)[@-]/;
        makeCall = function(left, right, msg) {
          if (!store.calls[left.uuid]) {
            return new Call(left, right, msg);
          }
        };
        if (store.agent_ext === ((_ref = msg.left.channel) != null ? typeof _ref.match === "function" ? (_ref2 = _ref.match(extMatch)) != null ? _ref2[1] : void 0 : void 0 : void 0)) {
          return makeCall(msg.left, msg.right, msg);
        } else if (store.agent_ext === ((_ref3 = msg.right.channel) != null ? typeof _ref3.match === "function" ? (_ref4 = _ref3.match(extMatch)) != null ? _ref4[1] : void 0 : void 0 : void 0)) {
          return makeCall(msg.right, msg.left, msg);
        } else if (msg.right.destination === ((_ref5 = msg.right.channel) != null ? typeof _ref5.match === "function" ? (_ref6 = _ref5.match(extMatch)) != null ? _ref6[1] : void 0 : void 0 : void 0)) {
          return makeCall(msg.right, msg.left, msg);
        } else if (msg.left.destination === ((_ref7 = msg.left.channel) != null ? typeof _ref7.match === "function" ? (_ref8 = _ref7.match(extMatch)) != null ? _ref8[1] : void 0 : void 0 : void 0)) {
          return makeCall(msg.left, msg.right, msg);
        } else if (msg.left.cid_number === ((_ref9 = msg.left.channel) != null ? typeof _ref9.match === "function" ? (_ref10 = _ref9.match(extMatch)) != null ? _ref10[1] : void 0 : void 0 : void 0)) {
          return makeCall(msg.left, msg.right, msg);
        } else if (msg.right.cid_number === ((_ref11 = msg.right.channel) != null ? typeof _ref11.match === "function" ? (_ref12 = _ref11.match(extMatch)) != null ? _ref12[1] : void 0 : void 0 : void 0)) {
          return makeCall(msg.right, msg.left, msg);
        }
      default:
        _results = [];
        for (key in msg) {
          value = msg[key];
          if (/unique|uuid/.test(key)) {
            if (call = store.calls[value]) {
              if (typeof call[_name = msg.tiny_action] === "function") {
                call[_name](msg);
              }
              return void 0;
            }
          }
        }
        return _results;
    }
  };
  onOpen = function() {
    return store.send({
      method: 'subscribe',
      agent: store.agent_name
    });
  };
  onClose = function() {
    $('#debug').text('Reconnecting...');
    return setTimeout(function() {
      $('#debug').text('');
      return setupWs();
    }, 5000);
  };
  onError = function(event) {
    return showError(event.data);
  };
  agentWantsStatusChange = function(a) {
    var curStatus;
    curStatus = $('#status a[class=active]').text();
    store.send({
      method: 'status',
      status: a.target.id,
      curStatus: curStatus
    });
    return false;
  };
  agentWantsStateChange = function(a) {
    var curState;
    curState = $('#state a[class=active').text();
    store.send({
      method: 'state',
      state: a.target.id,
      curState: curState
    });
    return false;
  };
  setupWs = function() {
    store.ws = new WebSocket(store.server);
    store.ws.onerror = onError;
    store.ws.onclose = onClose;
    store.ws.onopen = onOpen;
    return store.ws.onmessage = onMessage;
  };
  $(function() {
    var height, width, _ref;
    store.server = $('#server').text();
    store.agent_name = $('#agent_name').text();
    store.agent_ext = $('#agent_ext').text();
    store.call_template = $('#call-template').detach();
    $('#disposition').hide();
    $(document).keydown(function(event) {
      var bubble, keyCode;
      keyCode = event.keyCode;
      p(event.keyCode);
      bubble = true;
      $('#disposition button').each(function(i, button) {
        var buttonKeyCode, jbutton, keyName;
        jbutton = $(button);
        keyName = jbutton.attr('accesskey');
        buttonKeyCode = keyCodes[keyName];
        if (keyCode === buttonKeyCode) {
          if (typeof event.stopPropagation === "function") {
            event.stopPropagation();
          }
          if (typeof event.preventDefault === "function") {
            event.preventDefault();
          }
          bubble = false;
          return jbutton.click();
        }
      });
      return bubble;
    });
    $('#disposition').focus();
    $('#status a').live('click', agentWantsStatusChange);
    $('#state a').live('click', agentWantsStateChange);
    setTimeout(function() {
      return $(window).resize(function(event) {
        localStorage.setItem('agent.bar.width', top.outerWidth);
        localStorage.setItem('agent.bar.height', top.outerHeight);
        return true;
      });
    }, 100);
    _ref = [localStorage.getItem('agent.bar.width'), localStorage.getItem('agent.bar.height')], width = _ref[0], height = _ref[1];
    if (width && height) {
      top.resizeTo(width, height);
    }
    return setupWs();
  });
}).call(this);
