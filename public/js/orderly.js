(function() {
  var Agent, callTap, callTapToo, changeStatus, divmod, dropped, log, onClose, onMessage, onOpen, refreshAspects, secondsToTimestamp, setupWs, showAspect, statusOrStateToClass, syncSettingsFromAspects, timeFragmentPad, updateDeltas, withLabel;
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
  log = function(msg) {
    var _ref;
    return (_ref = window.console) != null ? typeof _ref.debug === "function" ? _ref.debug(msg) : void 0 : void 0;
  };
  statusOrStateToClass = function(str) {
    return str.toLowerCase().replace(/\W+/g, "-").replace(/^-+|-+$/g, "");
  };
  divmod = function(num, mod) {
    return [Math.floor(num / mod), Math.floor(num % mod)];
  };
  timeFragmentPad = function(fragment) {
    if (fragment > 9) {
      return fragment;
    } else {
      return "0" + fragment;
    }
  };
  secondsToTimestamp = function(given) {
    var fragment, hours, minutes, rest, seconds, _ref, _ref2;
    _ref = divmod(given, 60), rest = _ref[0], seconds = _ref[1];
    _ref2 = divmod(rest, 60), rest = _ref2[0], minutes = _ref2[1];
    hours = Math.floor(rest / 60);
    return ((function() {
      var _i, _len, _ref, _results;
      _ref = [hours, minutes, seconds];
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        fragment = _ref[_i];
        _results.push(timeFragmentPad(fragment));
      }
      return _results;
    })()).join(':');
  };
  Agent = (function() {
    function Agent(name) {
      this.name = name;
      this.id = "#" + name;
      this.initTr();
      this.setCalledTime(new Date(Date.now()));
    }
    Agent.prototype.initTr = function() {
      $('#agents').append("<div class='agent' id='" + this.name + "'>\n  <div class=\"extension-name\">\n    <span class='extension'></span>\n    <span class='name'></span>\n  </div>\n  <span class='status'></span>\n  <span class='state'></span>\n  <div class=\"cid\">\n    <span class='cid-name'></span>\n    <span class='cid-number'></span>\n  </div>\n  <span class='answered'></span>\n  <span class='called'></span>\n  <span class='queue'></span>\n</div>");
      return $("" + this.id + " .status").click(__bind(function(event) {
        var active, dialog;
        dialog = $("#status-dialog").clone(true);
        dialog.attr('id', '');
        dialog.addClass(this.id.slice(1));
        dialog.find('.agent-name').text(this.id.slice(1));
        active = dialog.find('.status a').filter(__bind(function(i, elt) {
          return $(elt).text() === this.status;
        }, this));
        active.addClass('active');
        return dialog.dialog({
          autoOpen: true,
          title: "" + this.extension + " " + this.name + " Details",
          modal: false,
          open: __bind(function(event, ui) {
            return dialog.find('.status .active').focus();
          }, this),
          close: function(event, ui) {
            return dialog.remove();
          }
        });
      }, this));
    };
    Agent.prototype.initializeFromMsg = function(name, msg) {
      var date;
      this.setNameExtension(name);
      this.setQueue(msg.cc_queue);
      this.setState(msg.state || 'Waiting');
      this.setStatus(msg.status || 'Available');
      if (msg.call_created != null) {
        log([msg.caller_cid_num, msg.caller_cid_name, msg.callee_cid_num, msg.caller_dest_num]);
        log(this.extension);
        date = new Date(Date.parse(msg.call_created));
        if (msg.caller_dest_num === this.extension) {
          log([1, msg.caller_cid_num, msg.caller_cid_name]);
          return this.answeredCall('Inbound Call', msg.caller_cid_name, msg.caller_cid_num, date, msg.call_uuid);
        } else {
          log([0, msg.caller_dest_num]);
          return this.answeredCall('Outbound Call', null, msg.caller_dest_num, date, msg.call_uuid);
        }
      } else if (msg.last_bridge_end != null) {
        date = new Date(Date.parse(msg.last_bridge_end));
        if (date.getFullYear() > 2009) {
          return this.setCalledTime(date);
        }
      }
    };
    Agent.prototype.answeredCall = function(direction, cidName, cidNumber, answeredTime, uuid) {
      log("Answered Call " + direction + ", " + cidName + ", " + cidNumber + ", " + uuid);
      answeredTime = answeredTime != null ? answeredTime : new Date(Date.now());
      this.setState(direction);
      this.setCid(cidName, cidNumber, uuid);
      return this.setAnsweredTime(answeredTime);
    };
    Agent.prototype.hungupCall = function(direction, msg) {
      this.setState('Waiting');
      this.setCidName('');
      this.setCidNumber('');
      this.setAnsweredTime();
      return this.setCalledTime(new Date(Date.now()));
    };
    Agent.prototype.adjustVisibility = function(effect, speed) {
      if (this.isVisible) {
        return $("" + this.id + ":hidden").show(effect, speed);
      } else {
        return $("" + this.id + ":visible").hide(effect, speed);
      }
    };
    Agent.prototype.tick = function() {
      if (this.answeredTime != null) {
        return this.setTalkTime(parseInt((Date.now() - this.answeredTime) / 1000, 10));
      } else if (this.calledTime != null) {
        return this.setWaitTime(parseInt((Date.now() - this.calledTime) / 1000, 10));
      }
    };
    Agent.prototype.setAnsweredTime = function(answeredTime) {
      this.answeredTime = answeredTime;
      if (answeredTime != null) {
        return this.tick();
      } else {
        return $("" + this.id + " .answered").text('');
      }
    };
    Agent.prototype.setCalledTime = function(calledTime) {
      this.calledTime = calledTime;
      if (calledTime != null) {
        return this.tick();
      } else {
        return $(this.id).children('.called').text('');
      }
    };
    Agent.prototype.setTalkTime = function(talkTime) {
      var tag;
      this.talkTime = talkTime;
      tag = $("" + this.id + " .answered");
      if (talkTime != null) {
        return tag.text(secondsToTimestamp(talkTime));
      } else {
        return tag.text(secondsToTimeStamp(this.answeredTime.getTime()));
      }
    };
    Agent.prototype.setWaitTime = function(waitTime) {
      var tag;
      this.waitTime = waitTime;
      tag = $("" + this.id + " .called");
      if (waitTime != null) {
        return tag.text(secondsToTimestamp(waitTime));
      } else {
        return tag.text('');
      }
    };
    Agent.prototype.setStatus = function(status) {
      var baseclass;
      this.status = status;
      baseclass = statusOrStateToClass(status);
      $("" + this.id + " .status").removeClass().addClass("status ui-state-hover " + baseclass);
      $(".status-dialog." + this.id.slice(1) + " .status a").removeClass('active');
      return $(".status-dialog." + this.id.slice(1) + " .status a." + baseclass).addClass('active');
    };
    Agent.prototype.setState = function(state) {
      var tag;
      this.state = state;
      tag = $("" + this.id + " .state");
      switch (state.toLowerCase()) {
        case 'in a queue call':
          tag.removeClass().addClass('state');
          return tag.text('Q');
        case 'inbound call':
          tag.removeClass().addClass('state ui-icon ui-icon-circle-arrow-w');
          if (tag.text !== 'Q') {
            return tag.text(state);
          }
        case 'waiting':
        case 'idle':
          tag.removeClass().addClass('state ui-icon ui-icon-clock');
          return tag.text('');
        case 'outbound call':
          tag.removeClass().addClass('state ui-icon ui-icon-circle-arrow-e');
          return tag.text(state);
        default:
          return tag.text(state);
      }
    };
    Agent.prototype.setQueue = function(queue) {
      this.queue = queue;
      return $("" + this.id + " .queue").text(queue);
    };
    Agent.prototype.setCid = function(name, number, uuid) {
      if ((name != null) && (number != null) && (uuid != null)) {
        if (name === number) {
          this.setCidName('');
          return this.setCidNumber(number, uuid);
        } else {
          this.setCidName(name);
          return this.setCidNumber(number, uuid);
        }
      } else {
        this.setCidName('');
        return this.setCidNumber(number, uuid);
      }
    };
    Agent.prototype.setCidName = function(cidName) {
      this.cidName = cidName;
      return $("" + this.id + " .cid-name").text(cidName);
    };
    Agent.prototype.setCidNumber = function(cidNumber, uuid) {
      this.cidNumber = cidNumber;
      return $("" + this.id + " .cid-number").html("<a class=\"calltaptoo\" name=\"" + this.name + "\" href=\"#\" rel=\"" + this.extension + "\" title=\"" + uuid + "\">" + cidNumber + "</a>");
    };
    Agent.prototype.setName = function(name) {
      this.name = name;
      return $("" + this.id + " .name").text(name);
    };
    Agent.prototype.setExtension = function(extension) {
      this.extension = extension;
      return $("" + this.id + " .extension").text(extension);
    };
    Agent.prototype.setNameExtension = function(nameExtension) {
      var ext, name, _ref;
      _ref = nameExtension.split('-', 2), ext = _ref[0], name = _ref[1];
      this.setExtension(ext);
      return this.setName(name.replace(/_/g, ' '));
    };
    Agent.prototype["bridge-agent-start"] = function(msg) {
      this.setQueue(msg.cc_queue);
      this.setCidName(msg.cc_caller_cid_name);
      this.setCidNumber(msg.cc_caller_cid_number);
      return this.setAnsweredTime(new Date(Date.now()));
    };
    Agent.prototype["bridge-agent-end"] = function(msg) {
      this.setAnsweredTime();
      this.setCalledTime(new Date(Date.now()));
      this.setCidName('');
      this.setCidNumber('');
      return this.setQueue('');
    };
    Agent.prototype["agent-state-change"] = function(msg) {
      this.setState(msg.cc_agent_state);
      switch (this.state) {
        case "Receiving":
          return this.setCalledTime(this.calledTime || new Date(Date.now()));
        case "In a queue call":
          return this.setAnsweredTime(new Date(Date.now()));
      }
    };
    Agent.prototype["agent-status-change"] = function(msg) {
      return this.setStatus(msg.cc_agent_status);
    };
    return Agent;
  })();
  Agent.all = {};
  Agent.withExtension = function(extension) {
    var agent, key, _ref;
    if (!(extension != null) || extension.length > 4) {
      return;
    }
    _ref = Agent.all;
    for (key in _ref) {
      agent = _ref[key];
      if (agent.extension === extension) {
        return agent;
      }
    }
    return;
  };
  Agent.findOrCreate = function(msg) {
    var agent, name;
    name = msg.cc_agent != null ? msg.cc_agent : msg.name;
    agent = Agent.all[name];
    if (!(agent != null) && name) {
      agent = new Agent(name);
      agent.initializeFromMsg(name, msg);
      Agent.all[name] = agent;
    }
    return agent;
  };
  updateDeltas = function() {
    var agent, key, _ref;
    _ref = Agent.all;
    for (key in _ref) {
      agent = _ref[key];
      agent.tick();
    }
    return;
  };
  changeStatus = function(event) {
    var a, agentId, status, ws;
    ws = event.data;
    a = $(event.target);
    agentId = a.closest('.status-dialog').find('.agent-name').text();
    status = statusOrStateToClass(a.text()).replace(/-/g, '_');
    ws.send(JSON.stringify({
      method: "status_of",
      agent: agentId,
      status: status
    }));
    return false;
  };
  callTap = function(event) {
    var a, agentId, self, ws;
    ws = event.data;
    a = $(event.target);
    agentId = a.closest('.status-dialog').find('.agent-name').text();
    self = $('#agent_name').text();
    return ws.send(JSON.stringify({
      method: 'calltap',
      agent: agentId,
      tapper: self
    }));
  };
  callTapToo = function(event) {
    var extension, name, phoneNumber, tapper, uuid, ws;
    try {
      ws = event.data;
      extension = this.rel;
      uuid = this.title;
      phoneNumber = this.text;
      name = this.name;
      tapper = $('#agent_name').text();
      log("tapping " + name + ": " + extension + " <=> " + phoneNumber + " (" + uuid + ") by " + tapper);
      ws.send(JSON.stringify({
        method: 'calltaptoo',
        name: name,
        extension: extension,
        tapper: tapper,
        uuid: uuid,
        phoneNumber: phoneNumber
      }));
    } catch (error) {
      log(error);
    }
    return false;
  };
  withLabel = function(name, fun) {
    var actual, json, label, labels, result;
    json = localStorage.getItem('labels');
    if (json != null) {
      labels = JSON.parse(json);
      label = labels[name] || {};
      labels[name] = label;
    } else {
      labels = {};
      label = {};
      labels[name] = label;
    }
    result = fun(label);
    actual = {};
    for (name in labels) {
      label = labels[name];
      if (/^[a-zA-Z][a-zA-Z0-9_-]*$/.test(name)) {
        actual[name] = label;
      }
    }
    localStorage.setItem('labels', JSON.stringify(actual));
    refreshAspects();
    return result;
  };
  dropped = function(agentId, labelName) {
    var activeLabelName;
    if (labelName === 'Trash') {
      activeLabelName = window.location.hash.slice(1);
      withLabel(activeLabelName, function(label) {
        delete label[agentId];
        return true;
      });
      return showAspect(activeLabelName);
    } else {
      return withLabel(labelName, function(label) {
        return label[agentId] = true;
      });
    }
  };
  refreshAspects = function() {
    var label, labels, name, tag;
    labels = JSON.parse(localStorage.getItem('labels'));
    $('.aspects .droppable').detach();
    for (name in labels) {
      label = labels[name];
      tag = $("<li class='droppable'><a href='#" + name + "'>" + name + "</a></li>");
      tag.insertBefore($('.aspects .trash'));
    }
    return $('.aspects .droppable, .aspects .trash').droppable({
      activeClass: "ui-state-active",
      hoverClass: "ui-state-hover",
      drop: function(event, ui) {
        var agentId, labelName;
        agentId = ui.draggable[0].id;
        labelName = $(this).text();
        return dropped(agentId, labelName);
      }
    });
  };
  showAspect = function(labelName) {
    var effect, speed, _ref;
    $('.aspects li').removeClass('active');
    $('.aspects li').each(function(i, li) {
      if ($(li).text() === labelName) {
        return $(li).addClass('active');
      }
    });
    _ref = ['fade', 'slow'], effect = _ref[0], speed = _ref[1];
    if (labelName === '') {
      $('.agent:hidden').show(effect, speed);
      $('.aspects .trash:visible').hide(effect, speed);
    } else {
      $('.aspects .trash:hidden').show(effect, speed);
      withLabel(labelName, function(label) {
        var agent, agentId, agents, key, value;
        agents = Agent.all;
        for (key in agents) {
          agent = agents[key];
          agent.isVisible = false;
        }
        for (agentId in label) {
          value = label[agentId];
          if (agent = agents[agentId]) {
            agent.isVisible = true;
          }
        }
        for (key in agents) {
          agent = agents[key];
          agent.adjustVisibility(effect, speed);
        }
        return true;
      });
    }
    return true;
  };
  syncSettingsFromAspects = function() {
    var label, name, _ref, _results;
    $('#settings-dialog .aspects li').detach();
    _ref = JSON.parse(localStorage.getItem('labels'));
    _results = [];
    for (name in _ref) {
      label = _ref[name];
      _results.push($('#settings-dialog .aspects').append($("<li>" + name + "<span class=\"ui-icon ui-icon-trash\"></span></li>")));
    }
    return _results;
  };
  onMessage = function(event) {
    var agent, debuggers, msg, _base, _i, _len, _ref;
    msg = JSON.parse(event.data);
    debuggers = /2616|2602|2613/;
    if (msg.agents) {
      log(msg.agents);
      _ref = msg.agents;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        agent = _ref[_i];
        Agent.findOrCreate(agent);
      }
    } else if (agent = Agent.findOrCreate(msg)) {
      if (typeof (_base = agent[msg.cc_action]).apply === "function") {
        _base.apply(agent, [msg]);
      }
    } else if (msg.event_name === 'CHANNEL_HANGUP') {
      if (debuggers.test(msg.caller_destination_number) || debuggers.test(msg.caller_caller_id_number)) {
        log("HANGUP");
        log(event.data);
      }
      if (agent = Agent.withExtension(msg.caller_destination_number)) {
        agent.hungupCall('Inbound Call', msg);
      }
      if (agent = Agent.withExtension(msg.caller_caller_id_number)) {
        agent.hungupCall('Outbound Call', msg);
      }
    } else if (msg.event_name === 'CHANNEL_ANSWER') {
      if (debuggers.test(msg.caller_destination_number) || debuggers.test(msg.caller_caller_id_number)) {
        log("ANSWER");
        log(event.data);
      }
      if (agent = Agent.withExtension(msg.caller_destination_number)) {
        agent.answeredCall('Inbound Call', msg.caller_caller_id_name, msg.caller_caller_id_number, null, msg.channel_call_uuid);
      }
      if (agent = Agent.withExtension(msg.caller_caller_id_number)) {
        agent.answeredCall('Outbound Call', msg.caller_callee_id_name, msg.caller_callee_id_number, null, msg.channel_call_uuid);
      }
    }
    return;
  };
  onOpen = function(event) {
    var agent;
    agent = $('#agent_name').text();
    this.send(JSON.stringify({
      method: 'listen',
      agent: agent
    }));
    this.intervalId = setInterval(updateDeltas, 1000);
    return refreshAspects();
  };
  onClose = function(event) {
    setTimeout(setupWs, 3000);
    return clearInterval(this.intervalId);
  };
  setupWs = function() {
    var server, ws;
    server = $('#server').text();
    ws = new WebSocket(server);
    ws.onmessage = onMessage;
    ws.onopen = onOpen;
    ws.onclose = onClose;
    $('#total-reset').click(function(event) {
      localStorage.clear();
      refreshAspects();
      syncSettingsFromAspects();
      return false;
    });
    $('.status-dialog .status a').die('click').live('click', ws, changeStatus);
    $('.status-dialog .calltap').die('click').live('click', ws, callTap);
    return $('a.calltaptoo').die('click').live('click', ws, callTapToo);
  };
  $(function() {
    setupWs();
    $('#agents').sortable();
    $('#agents').disableSelection();
    $('#settings-dialog .tabs').tabs();
    $(window).bind('hashchange', function(event) {
      var hash;
      hash = event.target.location.hash;
      return showAspect(hash.slice(1));
    });
    $('#settings-dialog .aspects .ui-icon-trash').live('click', function(event) {
      var json, labelName, labels;
      labelName = $(event.target).parent().text();
      json = localStorage.getItem('labels');
      labels = JSON.parse(json);
      delete labels[labelName];
      localStorage.setItem('labels', JSON.stringify(labels));
      refreshAspects();
      syncSettingsFromAspects();
      return false;
    });
    $('#settings-dialog').dialog({
      autoOpen: false,
      title: 'Settings',
      modal: true,
      open: syncSettingsFromAspects
    });
    $('nav .settings').click(function(event) {
      return $('#settings-dialog').dialog('open');
    });
    return $('#settings-dialog .add-aspect button').click(function(event) {
      var input, labelName;
      input = $('#input-text-add-aspect');
      labelName = input.val();
      withLabel(labelName, function(label) {
        return true;
      });
      input.val('');
      syncSettingsFromAspects();
      return false;
    });
  });
}).call(this);
