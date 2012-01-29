(function() {
  var BackboneWebSocket, Socket, p,
    __slice = Array.prototype.slice;

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
      this.tags = {};
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
        p('message', messageEvent.data);
        return _this.onmessage.apply(_this, arguments);
      };
      this.socket.onerror = function() {
        p.apply(null, ['error'].concat(__slice.call(arguments)));
        return _this.onerror.apply(_this, arguments);
      };
      this.socket.onopen = function() {
        p('open');
        _this.connected = true;
        return _this.onopen();
      };
      return this.socket.onclose = function() {
        p('close');
        _this.connected = false;
        return _this.onclose();
      };
    };

    Socket.prototype.onopen = function() {};

    Socket.prototype.onmessage = function(messageEvent) {
      var handler, parsed;
      parsed = JSON.parse(messageEvent.data);
      handler = this.tags[parsed.tag];
      return typeof handler === "function" ? handler(parsed) : void 0;
    };

    Socket.prototype.onclose = function() {};

    Socket.prototype.onerror = function(error) {};

    Socket.prototype.listen = function(tag, callback) {
      return this.tags[tag] = callback;
    };

    Socket.prototype.send = function() {
      var _ref;
      return (_ref = this.socket).send.apply(_ref, arguments);
    };

    return Socket;

  })();

  window.Rubyists.Socket = Socket;

  BackboneWebSocket = (function() {

    function BackboneWebSocket(options) {
      var _this = this;
      this.options = options;
      this.frame = 0;
      this.callbacks = {};
      this.socket = new Socket({
        server: this.options.server
      });
      this.socket.listen('backbone', function() {
        return _this.backboneRecv.apply(_this, arguments);
      });
      this.socket.onopen = function() {
        var _base;
        return typeof (_base = _this.options).onopen === "function" ? _base.onopen.apply(_base, arguments) : void 0;
      };
    }

    BackboneWebSocket.prototype.listen = function(tag, callback) {
      return this.socket.listen(tag, callback);
    };

    BackboneWebSocket.prototype.send = function() {
      var _ref;
      return (_ref = this.socket).send.apply(_ref, arguments);
    };

    BackboneWebSocket.prototype.say = function(msg) {
      return this.socket.send(JSON.stringify(msg));
    };

    BackboneWebSocket.prototype.backboneRecv = function(msg) {
      var body, callback, error;
      p.apply(null, ['backboneRecv'].concat(__slice.call(arguments)));
      if (callback = this.callbacks[msg.frame]) {
        delete this.callbacks[msg.frame];
        if (body = msg.ok) {
          return callback(body, true);
        } else if (error = msg.error) {
          return callback(error, false);
        }
      }
    };

    BackboneWebSocket.prototype.backboneSend = function(msg, callback) {
      var json, packet;
      this.frame += 1;
      packet = {
        tag: 'backbone',
        frame: this.frame,
        body: msg
      };
      if (callback != null) this.callbacks[this.frame] = callback;
      json = JSON.stringify(packet);
      p('send', json);
      return this.socket.send(json);
    };

    BackboneWebSocket.prototype.backboneRequest = function(given) {
      return this.backboneSend(given.data, function(response, status) {
        if (status === true) {
          return typeof given.success === "function" ? given.success(response) : void 0;
        } else {
          return typeof given.error === "function" ? given.error(response) : void 0;
        }
      });
    };

    BackboneWebSocket.prototype.backboneSync = function(method, model, options, changedAttributes) {
      return this["backboneSync" + model.url](method, model, options, changedAttributes);
    };

    BackboneWebSocket.prototype.sync = function() {
      var _this = this;
      return function() {
        return _this.backboneSync.apply(_this, arguments);
      };
    };

    BackboneWebSocket.prototype.backboneSyncAgent = function(method, model, options, changedAttributes) {
      var data;
      data = {
        method: method,
        url: model.url,
        id: model.id
      };
      if (method === 'update') {
        data.attributes = changedAttributes;
      } else {
        data.attributes = model;
      }
      if (data.attributes === false) {
        switch (method) {
          case 'update':
            return typeof options.success === "function" ? options.success(model.attributes) : void 0;
          case 'delete':
            return typeof options.success === "function" ? options.success({
              id: model.id
            }) : void 0;
          case 'create':
            return typeof options.success === "function" ? options.success({
              id: model.id
            }) : void 0;
          case 'read':
            return typeof options.success === "function" ? options.success(model.attributes) : void 0;
        }
      } else {
        return this.backboneRequest({
          data: data,
          success: options.success,
          error: options.error
        });
      }
    };

    BackboneWebSocket.prototype.backboneSyncCall = function(method, model, options, changedAttributes) {
      p('Call', method, model.id, model.attributes);
      switch (method) {
        case 'update':
          return typeof options.success === "function" ? options.success(model.attributes) : void 0;
        case 'delete':
          return typeof options.success === "function" ? options.success({
            id: model.id
          }) : void 0;
        case 'create':
          return typeof options.success === "function" ? options.success({
            id: model.id
          }) : void 0;
        case 'read':
          return typeof options.success === "function" ? options.success(model.attributes) : void 0;
      }
    };

    return BackboneWebSocket;

  })();

  window.Rubyists.BackboneWebSocket = BackboneWebSocket;

}).call(this);
