(function() {
  var Agent, CallView, DispositionView, Model, OriginateView, Ribbon, Socket, StateView, StatusView, TransferView, View, p,
    __hasProp = Object.prototype.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

  p = function() {
    var _ref;
    return (_ref = window.console) != null ? _ref.debug.apply(_ref, arguments) : void 0;
  };

  View = (function(_super) {

    __extends(View, _super);

    function View() {
      View.__super__.constructor.apply(this, arguments);
    }

    return View;

  })(Backbone.View);

  Model = (function(_super) {

    __extends(Model, _super);

    function Model() {
      Model.__super__.constructor.apply(this, arguments);
    }

    return Model;

  })(Backbone.Model);

  Agent = (function(_super) {

    __extends(Agent, _super);

    function Agent() {
      Agent.__super__.constructor.apply(this, arguments);
    }

    Agent.prototype.url = 'Agent';

    Agent.prototype.persist = ['status', 'state'];

    return Agent;

  })(Model);

  CallView = (function(_super) {

    __extends(CallView, _super);

    function CallView() {
      CallView.__super__.constructor.apply(this, arguments);
    }

    CallView.prototype.tagName = 'div';

    CallView.prototype.el = '#call';

    CallView.prototype.initialize = function() {
      return $(this.el).hide();
    };

    return CallView;

  })(View);

  DispositionView = (function(_super) {

    __extends(DispositionView, _super);

    function DispositionView() {
      DispositionView.__super__.constructor.apply(this, arguments);
    }

    DispositionView.prototype.tagName = 'form';

    DispositionView.prototype.el = '#disposition';

    DispositionView.prototype.initialize = function() {
      return $(this.el).hide();
    };

    return DispositionView;

  })(View);

  TransferView = (function(_super) {

    __extends(TransferView, _super);

    function TransferView() {
      TransferView.__super__.constructor.apply(this, arguments);
    }

    TransferView.prototype.tagName = 'form';

    TransferView.prototype.el = '#transfer';

    TransferView.prototype.initialize = function() {
      return $(this.el).hide();
    };

    return TransferView;

  })(View);

  OriginateView = (function(_super) {

    __extends(OriginateView, _super);

    function OriginateView() {
      OriginateView.__super__.constructor.apply(this, arguments);
    }

    OriginateView.prototype.tagName = 'form';

    OriginateView.prototype.el = '#originate';

    OriginateView.prototype.initialize = function() {
      return $(this.el).hide();
    };

    return OriginateView;

  })(View);

  StatusView = (function(_super) {

    __extends(StatusView, _super);

    function StatusView() {
      StatusView.__super__.constructor.apply(this, arguments);
    }

    StatusView.prototype.tagName = 'ul';

    StatusView.prototype.el = '#status';

    StatusView.prototype.events = {
      'click .available': 'available',
      'click .on_break': 'on_break',
      'click .logged_out': 'logged_out'
    };

    StatusView.prototype.statusMap = {
      'available': '.available',
      'available (on demand)': '.available',
      'on break': 'on_break',
      'logged out': 'logged_out'
    };

    StatusView.prototype.initialize = function() {
      return this.options.agent.bind('change:status', this.render, this);
    };

    StatusView.prototype.render = function() {
      var klass, status;
      status = this.options.agent.get('status');
      klass = this.statusMap[status.toLowerCase];
      this.$('button').removeClass('active');
      this.$(klass).addClass('active');
      return this;
    };

    StatusView.prototype.available = function() {
      return this.options.agent.save({
        status: 'Available'
      });
    };

    StatusView.prototype.on_break = function() {
      return this.options.agent.save({
        status: 'On Break'
      });
    };

    StatusView.prototype.logged_out = function() {
      return this.options.agent.save({
        status: 'Logged Out'
      });
    };

    return StatusView;

  })(View);

  StateView = (function(_super) {

    __extends(StateView, _super);

    function StateView() {
      StateView.__super__.constructor.apply(this, arguments);
    }

    StateView.prototype.tagName = 'ul';

    StateView.prototype.el = '#state';

    StateView.prototype.initialize = function() {
      return this.options.agent.bind('change:state', this.render, this);
    };

    StateView.prototype.render = function() {
      var klass, state;
      state = this.options.agent.get('state');
      klass = state.replace(/\s+/g, "_");
      this.$('button').removeClass('active');
      this.$(klass).addClass('active');
      return this;
    };

    return StateView;

  })(View);

  Ribbon = (function(_super) {

    __extends(Ribbon, _super);

    function Ribbon() {
      Ribbon.__super__.constructor.apply(this, arguments);
    }

    Ribbon.prototype.tagName = 'div';

    Ribbon.prototype.el = '#ribbon';

    Ribbon.prototype.initialize = function() {
      _.bindAll(this, 'render');
      this.agent = this.options.agent;
      this.agent.bind('change', this.render);
      this.agent.fetch();
      this.statusView = new StatusView({
        agent: this.agent
      });
      this.stateView = new StateView({
        agent: this.agent
      });
      this.dispositionView = new DispositionView({
        agent: this.agent
      });
      this.callView = new CallView({
        agent: this.agent
      });
      this.originateView = new OriginateView({
        agent: this.agent
      });
      return this.transferView = new TransferView({
        agent: this.agent
      });
    };

    Ribbon.prototype.render = function() {
      this.dispositionView.render();
      return this;
    };

    return Ribbon;

  })(View);

  Backbone.sync = Rubyists.BackboneWebSocketSync;

  Socket = (function(_super) {

    __extends(Socket, _super);

    function Socket() {
      Socket.__super__.constructor.apply(this, arguments);
    }

    Socket.prototype.onopen = function() {
      var agent, ribbon;
      agent = new Agent({
        name: $('#agent_name').text(),
        extension: $('#agent_ext').text()
      });
      ribbon = new Ribbon({
        agent: agent
      });
      return ribbon.render();
    };

    return Socket;

  })(Rubyists.Socket);

  window.Ribbon = Ribbon;

  $(function() {
    var server;
    server = $('#server').text();
    return Rubyists.syncSocket = new Socket({
      server: server
    });
  });

}).call(this);
