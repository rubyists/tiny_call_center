(function() {
  var Call, agentStateChange, agentStatusChange, agentWantsCallHangup, agentWantsCallTransfer, agentWantsStateChange, agentWantsStatusChange, agentWantsToBeCalled, agentWantsToLogout, currentState, currentStatus, divmod, formatInterval, formatPhoneNumber, keyCodes, onClose, onError, onMessage, onOpen, p, setupWs, showError, store;
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
  p = function() {
    var _ref;
    return (_ref = window.console) != null ? typeof _ref.debug === "function" ? _ref.debug(arguments) : void 0 : void 0;
  };
  showError = function(msg) {
    return $('#error').text(msg);
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
  Call = (function() {
    function Call(local_leg, remote_leg, msg) {
      this.uuid = remote_leg.uuid;
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
        cidNumber: $('.cid-number', this.sel),
        cidName: $('.cid-name', this.sel),
        answered: $('.answered', this.sel),
        called: $('.called', this.sel),
        destination: $('.destination', this.sel),
        queueName: $('.queue-name', this.sel),
        uuid: $('.uuid', this.sel),
        channel: $('.channel', this.sel)
      };
      this.dom.cidNumber.text(formatPhoneNumber(this.remote_leg.cid_number));
      this.dom.cidName.text(this.remote_leg.cid_name);
      this.dom.destination.text(formatPhoneNumber(this.remote_leg.destination));
      this.dom.queueName.text(this.local_leg.queue);
      this.dom.uuid.text(this.remote_leg.uuid);
      return this.dom.channel.text(this.local_leg.channel);
    };
    Call.prototype['bridge-agent-start'] = function(msg) {
      this.dom.cidName.text(msg.cc_caller_cid_name);
      this.dom.cidNumber.text(formatPhoneNumber(msg.cc_caller_cid_number));
      return this.talkingStart(new Date(Date.now()));
    };
    Call.prototype['bridge-agent-end'] = function(msg) {
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
        return this.dom.answered.text("" + (this.answered.toLocaleTimeString()) + " " + (formatInterval(this.answered)));
      }, this), 1000);
    };
    Call.prototype.talkingEnd = function() {
      clearInterval(this.answeredInterval);
      delete store.calls[this.uuid];
      return this.askDisposition();
    };
    Call.prototype.askDisposition = function() {
      return;
      if (this.local_leg.cid_number === "8675309" || this.local_leg.destination === "19999") {
        this.sel.remove();
        return;
      }
      $('#disposition button').one('click', __bind(function(event) {
        var jbutton;
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
    $('.change-status').removeClass('active inactive');
    return tag.addClass('active');
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
    $('.change-state').removeClass('active inactive');
    return tag.addClass('active');
  };
  agentStateChange = function(msg) {
    var state;
    state = msg.cc_agent_state.replace(/\s+/g, "_");
    return currentState($("#" + state));
  };
  onMessage = function(event) {
    var call, extMatch, key, makeCall, msg, value, _name, _ref, _ref10, _ref11, _ref12, _ref2, _ref3, _ref4, _ref5, _ref6, _ref7, _ref8, _ref9;
    msg = JSON.parse(event.data);
    p(msg);
    switch (msg.tiny_action) {
      case 'status_change':
        agentStatusChange(msg);
        break;
      case 'state_change':
        agentStateChange(msg);
        break;
      case 'call_start':
        extMatch = /(?:^|\/)(?:sip:)?(\d+)[@-]/;
        makeCall = function(left, right, msg) {
          var call, uuid;
          uuid = right.uuid;
          if (store.calls[uuid]) {
            return p("Found duplicate Call", store.calls[uuid]);
          } else {
            call = new Call(left, right, msg);
            return p("Created Call", call);
          }
        };
        if (store.agent_ext === ((_ref = msg.left.channel) != null ? typeof _ref.match === "function" ? (_ref2 = _ref.match(extMatch)) != null ? _ref2[1] : void 0 : void 0 : void 0)) {
          makeCall(msg.left, msg.right, msg);
        } else if (store.agent_ext === ((_ref3 = msg.right.channel) != null ? typeof _ref3.match === "function" ? (_ref4 = _ref3.match(extMatch)) != null ? _ref4[1] : void 0 : void 0 : void 0)) {
          makeCall(msg.right, msg.left, msg);
        } else if (msg.right.destination === ((_ref5 = msg.right.channel) != null ? typeof _ref5.match === "function" ? (_ref6 = _ref5.match(extMatch)) != null ? _ref6[1] : void 0 : void 0 : void 0)) {
          makeCall(msg.right, msg.left, msg);
        } else if (msg.left.destination === ((_ref7 = msg.left.channel) != null ? typeof _ref7.match === "function" ? (_ref8 = _ref7.match(extMatch)) != null ? _ref8[1] : void 0 : void 0 : void 0)) {
          makeCall(msg.left, msg.right, msg);
        } else if (msg.left.cid_number === ((_ref9 = msg.left.channel) != null ? typeof _ref9.match === "function" ? (_ref10 = _ref9.match(extMatch)) != null ? _ref10[1] : void 0 : void 0 : void 0)) {
          makeCall(msg.left, msg.right, msg);
        } else if (msg.right.cid_number === ((_ref11 = msg.right.channel) != null ? typeof _ref11.match === "function" ? (_ref12 = _ref11.match(extMatch)) != null ? _ref12[1] : void 0 : void 0 : void 0)) {
          makeCall(msg.right, msg.left, msg);
        }
        break;
      default:
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
    }
    if ($.isEmptyObject(store.calls)) {
      return $('#callme').show();
    } else {
      return $('#callme').hide();
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
    curStatus = $('.change-status[class=active]').text();
    store.send({
      method: 'status',
      status: a.target.id,
      curStatus: curStatus
    });
    return false;
  };
  agentWantsStateChange = function(a) {
    var curState;
    curState = $('.change-state[class=active]').text();
    store.send({
      method: 'state',
      state: a.target.id.replace(/_/g, ' '),
      curState: curState
    });
    return false;
  };
  agentWantsToBeCalled = __bind(function(event) {
    store.send({
      method: 'callme'
    });
    return false;
  }, this);
  agentWantsCallHangup = function(event) {
    var call_div, uuid;
    call_div = $(event.target).closest('.call');
    uuid = $('.uuid', call_div).text();
    store.send({
      method: 'hangup',
      uuid: uuid,
      cause: "Agent " + store.agent_name + " wants to hang up"
    });
    return false;
  };
  agentWantsCallTransfer = function(clickEvent) {
    var call_div, uuid;
    call_div = $(clickEvent.target).closest('.call');
    uuid = $('.uuid', call_div).text();
    $('#transfer-cancel').click(__bind(function(cancelEvent) {
      $('#transfer').hide();
      return false;
    }, this));
    $('#transfer').submit(__bind(function(submitEvent) {
      store.send({
        method: 'transfer',
        uuid: uuid,
        dest: $('#transfer-dest').val()
      });
      store.calls[uuid].talkingEnd();
      $('#transfer').hide();
      return false;
    }, this));
    $('#transfer').show();
    return false;
  };
  agentWantsToLogout = function(clickEvent) {
    return window.location.pathname = "/accounts/logout";
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
    if (store.server === '') {
      store.server = "ws://" + location.hostname + ":8080/websocket";
    }
    store.agent_name = $('#agent_name').text();
    store.agent_ext = $('#agent_ext').text();
    store.call_template = $('#call-template').detach();
    $('#disposition').hide();
    $('#transfer').hide();
    $(document).keydown(function(event) {
      var bubble, keyCode;
      keyCode = event.keyCode;
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
    $('.change-status').live('click', agentWantsStatusChange);
    $('.change-state').live('click', agentWantsStateChange);
    $('.call .hangup').live('click', agentWantsCallHangup);
    $('.call .transfer').live('click', agentWantsCallTransfer);
    $('.callme').live('click', agentWantsToBeCalled);
    $('.logout').live('click', agentWantsToLogout);
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
