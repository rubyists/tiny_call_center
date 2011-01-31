(function() {
  var Call, agentStateChange, agentStatusChange, currentStatus, keyCodes, onClose, onError, onMessage, onOpen, p, setupWs, showError, store;
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
  store = {
    calls: {}
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
    function Call(uuid, msg) {
      var action;
      this.uuid = uuid;
      this.prepareDOM();
      action = (msg.cc_action || msg.event_name || msg.tiny_action).toLowerCase();
      if (typeof this[action] === "function") {
        this[action](msg);
      }
    }
    Call.prototype.prepareDOM = function() {
      this.sel = store.call_template.clone();
      $('#calls').append(this.sel);
      return this.dom = {
        state: $('.state', this.sel),
        cidNumber: $('.cid-number', this.sel),
        cidName: $('.cid-name', this.sel),
        answered: $('.answered', this.sel),
        called: $('.called', this.sel)
      };
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
      if (msg.caller_unique_id === this.uuid) {
        if (msg.caller_destination_number === store.agent_ext) {
          return this.talkingEnd();
        } else if (msg.caller_caller_id_number === store.agent_ext) {
          return this.talkingEnd();
        }
      }
    };
    Call.prototype.channel_answer = function(msg) {
      if (msg.caller_destination_number === store.agent_ext) {
        return this.answeredCall('Inbound Call', msg.caller_caller_id_name, msg.caller_caller_id_number, msg.channel_call_uuid || msg.unique_id);
      } else if (msg.caller_caller_id_number === store.agent_ext) {
        return this.answeredCall('Outbound Call', msg.caller_destination_number, msg.caller_callee_id_number, msg.channel_call_uuid || msg.unique_id);
      }
    };
    Call.prototype.answeredCall = function(direction, cidName, cidNumber, uuid) {
      this.dom.cidNumber.text(cidNumber);
      if (cidName != null) {
        this.dom.cidName.text(cidName);
      }
      this.dom.state.text('On A Call');
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
      this.answered = null;
      clearInterval(this.answeredInterval);
      return setTimeout(__bind(function() {
        this.dom.remove();
        return delete store.calls[this.uuid];
      }, this), 1000);
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
        return currentStatus($('#available'));
      case 'available (on demand)':
        return currentStatus($('#available_on_demand'));
      case 'on break':
        return currentStatus($('#on_break'));
      case 'logged out':
        return currentStatus($('#logged_out'));
    }
  };
  agentStateChange = function(msg) {
    return $('#state').text(msg.cc_agent_state);
  };
  onMessage = function(event) {
    var action, call, msg, uuid;
    msg = JSON.parse(event.data);
    p(msg);
    switch (msg.cc_action) {
      case 'agent-status-change':
        return agentStatusChange(msg);
      case 'agent-state-change':
        return agentStateChange(msg);
      default:
        uuid = msg.uuid || msg.call_uuid || msg.channel_call_uuid || msg.unique_id;
        if (call = store.calls[uuid]) {
          action = (msg.cc_action || msg.event_name || msg.tiny_action).toLowerCase();
          return call[action](msg);
        } else {
          call = new Call(uuid, msg);
          return store.calls[uuid] = call;
        }
    }
  };
  onOpen = function() {
    return this.send(JSON.stringify({
      method: 'subscribe',
      agent: store.agent_name
    }));
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
    store.agent_ext = store.agent_name.split('-', 2)[0];
    store.call_template = $('#call-template').detach();
    $('#disposition button').click(function(event) {
      alert($(event.target).text());
      $('#disposition').focus();
      return false;
    });
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
    $('#status a').live('click', function(a) {
      var curStatus;
      try {
        curStatus = $('a[class=active]').text();
        store.ws.send(JSON.stringify({
          method: 'status',
          status: a.target.id,
          curStatus: curStatus
        }));
      } catch (error) {
        showError(error);
      }
      return false;
    });
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
