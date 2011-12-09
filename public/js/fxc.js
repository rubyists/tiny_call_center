(function() {
  var days, divmod, formatTime, onDayRangeSlide, onTimeRangeSlide, p, updateDayLabels, updateTimeLabels;
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
  p = function() {
    var _ref;
    return (_ref = window.console) != null ? typeof _ref.log === "function" ? _ref.log(arguments) : void 0 : void 0;
  };
  divmod = function(num1, num2) {
    return [num1 / num2, num1 % num2];
  };
  formatTime = function(totalMinutes) {
    var hours, minutes, _ref;
    _ref = divmod(totalMinutes, 60), hours = _ref[0], minutes = _ref[1];
    return sprintf("%02d:%02d", hours, minutes);
  };
  days = [];
  onTimeRangeSlide = function(event, ui) {
    return updateTimeLabels(ui.values);
  };
  onDayRangeSlide = function(event, ui) {
    return updateDayLabels(ui.values);
  };
  updateTimeLabels = function(values) {
    var from, to;
    from = values[0], to = values[1];
    $('#time-from').val(from);
    $('#time-to').val(to);
    return $('#time-show').text("" + (formatTime(from)) + " - " + (formatTime(to)));
  };
  updateDayLabels = function(values) {
    var from, to;
    from = values[0], to = values[1];
    $('#day-from').val(from);
    $('#day-to').val(to);
    return $('#day-show').text("" + days[from] + " - " + days[to]);
  };
  $(function() {
    var fromDay, fromMinutes, name, toDay, toMinutes;
    fromMinutes = parseInt($('#time-from').val(), 10);
    toMinutes = parseInt($('#time-to').val(), 10);
    $('#timerange').slider({
      range: true,
      min: 0,
      max: 1440,
      step: 15,
      values: [fromMinutes, toMinutes],
      slide: onTimeRangeSlide
    });
    updateTimeLabels([fromMinutes, toMinutes]);
    days = (function() {
      var _i, _len, _ref, _results;
      _ref = ['mo', 'tu', 'we', 'th', 'fr', 'sa', 'su'];
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        name = _ref[_i];
        _results.push($("input[name='" + name + "']").val());
      }
      return _results;
    })();
    fromDay = parseInt($('#day-from').val(), 10);
    toDay = parseInt($('#day-to').val(), 10);
    $('#dayrange').slider({
      range: true,
      min: 0,
      max: 6,
      step: 1,
      values: [fromDay, toDay],
      slide: onDayRangeSlide
    });
    updateDayLabels([fromDay, toDay]);
    $('#add-tod-dialog').dialog({
      autoOpen: false,
      height: 400,
      width: 500,
      modal: true,
      buttons: {
        'Create TOD': function() {
          return $.post('/fxc/user/add_route', {
            uid: $('#user-id').val(),
            from_minute: parseInt($('#time-from').val(), 10),
            to_minute: parseInt($('#time-to').val(), 10),
            from_wday: parseInt($('#day-from').val(), 10),
            to_wday: parseInt($('#day-to').val(), 10),
            target: $('#route-ext').val()
          }, {
            success: __bind(function(data, textStatus, jqXHR) {
              p(this);
              p(arguments);
              return $(this).dialog('close');
            }, this)
          });
        },
        'Cancel': function() {
          return $(this).dialog('close');
        }
      }
    });
    $('#add-tod').button().click(function() {
      return $('#add-tod-dialog').dialog('open');
    });
    $('.sortable').sortable({
      placeholder: 'ui-state-highlight',
      update: function(event, ui) {
        p({
          event: event,
          ui: ui
        });
        return $.post('/fxc/user/sort_route', {
          uid: $('#user-id').val()
        }, {
          success: __bind(function(data, textStatus, jqXHR) {
            return p(arguments);
          }, this)
        });
      }
    });
    return $('.sortable').disableSelection();
  });
}).call(this);
