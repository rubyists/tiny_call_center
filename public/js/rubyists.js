(function() {
  var BackboneWebSocketSync, Socket, p;

  p = function() {
    var _ref;
    return (_ref = window.console) != null ? typeof _ref.debug === "function" ? _ref.debug.apply(_ref, arguments) : void 0 : void 0;
  };

  window.Rubyists || (window.Rubyists = {});

  Socket = (function() {

    function Socket(options) {
      this.options = options;
      this.webSocket = "MozWebSocket" in window ? MozWebSocket : WebSocket;
      this.connected = false;
      this.frame = 0;
      this.callbacks = {};
      this.connect();
    }

    Socket.prototype.connect = function() {
      var _this = this;
      return this.reconnector = setInterval((function() {
        return _this.reconnect();
      }), 1000);
    };

    Socket.prototype.reconnect = function() {
      var _this = this;
      if (this.connected) return;
      this.socket = new this.webSocket(this.options.server);
      this.socket.onmessage = function(messageEvent) {
        var body, callback, error, parsed;
        parsed = JSON.parse(messageEvent.data);
        p('parsed', parsed);
        if (callback = _this.callbacks[parsed.frame]) {
          delete _this.callbacks[parsed.frame];
          if (body = parsed.ok) {
            callback(body, true);
            return _this.onmessage(body);
          } else if (error = parsed.error) {
            callback(error, false);
            return _this.onmessage(error);
          }
        }
      };
      this.socket.onerror = function() {
        return _this.onerror.apply(_this, arguments);
      };
      this.socket.onopen = function() {
        _this.connected = true;
        return _this.onopen.apply(_this, arguments);
      };
      return this.socket.onclose = function() {
        _this.connected = false;
        return _this.onclose.apply(_this, arguments);
      };
    };

    Socket.prototype.onopen = function() {
      return p('open', this);
    };

    Socket.prototype.onmessage = function(body) {
      return p('message', body);
    };

    Socket.prototype.onclose = function() {
      return p('close', this);
    };

    Socket.prototype.onerror = function(error) {
      return p('error', error);
    };

    Socket.prototype.say = function(message, callback) {
      var packet;
      this.frame += 1;
      packet = {
        frame: this.frame,
        body: message
      };
      this.callbacks[this.frame] = callback;
      p({
        packet: packet
      });
      return this.socket.send(JSON.stringify(packet));
    };

    Socket.prototype.request = function(given) {
      return this.say(given.data, function(response, status) {
        if (status === true) {
          return typeof given.success === "function" ? given.success(response) : void 0;
        } else {
          return typeof given.error === "function" ? given.error(response) : void 0;
        }
      });
    };

    return Socket;

  })();

  window.Rubyists.Socket = Socket;

  BackboneWebSocketSync = function(method, model, options) {
    var data;
    data = {
      method: method,
      url: model.url,
      id: model.id,
      attributes: model
    };
    switch (method) {
      case 'update':
        p('changed', model.changedAttributes());
        data.attributes = model.changedAttributes();
    }
    return Rubyists.syncSocket.request({
      data: data,
      success: options.success,
      error: options.error
    });
  };

  window.Rubyists.BackboneWebSocketSync = BackboneWebSocketSync;

}).call(this);
