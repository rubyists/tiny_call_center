(function() {
  var Call, agentStateChange, agentStatusChange, currentStatus, onClose, onError, onMessage, onOpen, p, setupWs, showError, store;
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
  store = {
    calls: {}
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
      this.waitingStart();
      action = (msg.cc_action || msg.event_name || msg.ws_action).toLowerCase();
      if (typeof this[action] === "function") {
        this[action](msg);
      }
    }
    Call.prototype.initial_status = function(msg) {
      switch (store.agent_ext) {
        case msg.caller_cid_num:
          $('#cid-number').text(msg.callee_cid_num);
          return this.talkingStart(new Date(Date.parse(msg.call_created)));
        case msg.callee_cid_num:
          $('#cid-number').text(msg.caller_cid_num);
          $('#cid-name').text(msg.caller_cid_name);
          return this.talkingStart(new Date(Date.parse(msg.call_created)));
      }
    };
    Call.prototype['bridge-agent-start'] = function(msg) {
      $('#cid-name').text(msg.cc_caller_cid_name);
      $('#cid-number').text(msg.cc_caller_cid_number);
      return this.talkingStart(new Date(Date.now()));
    };
    Call.prototype['bridge-agent-end'] = function(msg) {
      $('#cid-name').text('');
      $('#cid-number').text('');
      return this.talkingEnd();
    };
    Call.prototype.channel_hangup = function(msg) {
      if (msg.caller_unique_id === this.uuid) {
        if (msg.caller_destination_number === store.agent_ext) {
          return this.hungupCall('Inbound Call', msg);
        } else if (msg.caller_caller_id_number === store.agent_ext) {
          return this.hungupCall('Outbound Call', msg);
        }
      }
    };
    Call.prototype.hungupCall = function(direction, msg) {
      $('#cid-number').text('');
      $('#cid-name').text('');
      $('#state').text('Waiting');
      return this.talkingEnd();
    };
    Call.prototype.channel_answer = function(msg) {
      if (msg.caller_destination_number === store.agent_ext) {
        return this.answeredCall('Inbound Call', msg.caller_caller_id_name, msg.caller_caller_id_number, msg.channel_call_uuid || msg.unique_id);
      } else if (msg.caller_caller_id_number === store.agent_ext) {
        return this.answeredCall('Outbound Call', msg.caller_destination_number, msg.caller_callee_id_number, msg.channel_call_uuid || msg.unique_id);
      }
    };
    Call.prototype.answeredCall = function(direction, cidName, cidNumber, uuid) {
      $('#cid-number').text(cidNumber);
      if (cidName != null) {
        $('#cid-name').text(cidName);
      }
      $('#state').text('On A Call');
      return this.talkingStart(new Date(Date.now()));
    };
    Call.prototype.talkingStart = function(answeredTime) {
      if (this.answered != null) {
        return;
      }
      this.answered = answeredTime || new Date(Date.now());
      this.answeredInterval = setInterval(__bind(function() {
        var talkTime;
        talkTime = parseInt((Date.now() - this.answered) / 1000, 10);
        return $('#answered').text("" + (this.answered.toLocaleTimeString()) + " (" + talkTime + "s)");
      }, this), 1000);
      return this.waitingEnd();
    };
    Call.prototype.talkingEnd = function() {
      this.answered = null;
      clearInterval(this.answeredInterval);
      $('#answered').text('');
      return this.waitingStart();
    };
    Call.prototype.waitingStart = function() {
      if (this.called != null) {
        return;
      }
      this.called = new Date(Date.now());
      return this.calledInterval = setInterval(__bind(function() {
        var waitTime;
        waitTime = parseInt((Date.now() - this.called) / 1000, 10);
        return $('#called').text("" + (this.called.toLocaleTimeString()) + " (" + waitTime + "s)");
      }, this), 1000);
    };
    Call.prototype.waitingEnd = function() {
      this.called = null;
      clearInterval(this.calledInterval);
      return $('#called').text('');
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
        agentStatusChange(msg);
        break;
      case 'agent-state-change':
        agentStateChange(msg);
        break;
      default:
        uuid = msg.uuid || msg.call_uuid || msg.channel_call_uuid || msg.unique_id;
        p(uuid);
        if (call = store.calls[uuid]) {
          action = (msg.cc_action || msg.event_name || msg.ws_action).toLowerCase();
          p(action);
          call[action](msg);
        } else {
          call = new Call(uuid, msg);
          store.calls[uuid] = call;
        }
    }
    return p(store);
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
    $('#disposition a').click(function(event) {
      return $('#disposition').hide();
    });
    $('#disposition').hide();
    $(document).keydown(function(event) {
      var bubble, keyCode;
      keyCode = event.keyCode;
      bubble = true;
      $('#disposition a').each(function(x, a) {
        var code, ja;
        ja = $(a);
        code = parseInt(ja.attr('class').split('-')[1], 10);
        if (code === keyCode) {
          if (typeof event.stopPropagation === "function") {
            event.stopPropagation();
          }
          if (typeof event.preventDefault === "function") {
            event.preventDefault();
          }
          bubble = false;
          return ja.click();
        }
      });
      return bubble;
    });
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
