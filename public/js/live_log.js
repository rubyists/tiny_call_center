(function() {
  var Controller, Socket, p, store;
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
  p = function() {
    var _ref;
    return (_ref = window.console) != null ? typeof _ref.debug == "function" ? _ref.debug(arguments) : void 0 : void 0;
  };
  store = {};
  Socket = (function() {
    function Socket(controller) {
      this.controller = controller;
      this.connect();
    }
    Socket.prototype.connect = function() {
      this.ws = new WebSocket(store.server);
      return this.reconnector = setInterval(__bind(function() {
        if (!this.connected) {
          this.ws = new WebSocket(store.server);
          return this.prepareWs();
        }
      }, this), 1000);
    };
    Socket.prototype.prepareWs = function() {
      this.ws.onopen = __bind(function() {
        this.say({
          method: 'subscribe',
          agent: store.agent
        });
        return this.connected = true;
      }, this);
      this.ws.onmessage = __bind(function(message) {
        var data;
        data = JSON.parse(message.data);
        return this.controller.dispatch(data);
      }, this);
      this.ws.onclose = __bind(function() {
        p("Closing WebSocket");
        return this.connected = false;
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
      return p(msg);
    };
    return Controller;
  })();
  $(function() {
    store.server = $('#server').text();
    if (store.server === '') {
      store.server = "ws://" + location.hostname + ":8081/websocket";
    }
    store.agent = $('#agent_name').text();
    store.protoLog = $('#proto-log').detach();
    store.ws = new Socket(new Controller());
    return window.tcc_store = store;
  });
}).call(this);
