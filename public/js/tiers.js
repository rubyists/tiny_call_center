(function() {
  var p;
  p = function(obj) {
    var _ref;
    return (_ref = window.console) != null ? typeof _ref.debug == "function" ? _ref.debug(obj) : void 0 : void 0;
  };
  $(function() {
    var root;
    root = $('.tiers_agents .tiers');
    return root.each(function(i, tiers) {
      var control, klass, newSelect, option, option_classes, options, select, status_classes, _i, _len;
      select = $('select[name=status]', tiers).first();
      options = [];
      $('option', select).each(function(i, o) {
        return options.push($(o).val());
      });
      option_classes = [];
      status_classes = {};
      for (_i = 0, _len = options.length; _i < _len; _i++) {
        option = options[_i];
        klass = option.toLowerCase().replace(/\W+/g, "-").replace(/^-+|-+$/, "");
        status_classes[option] = klass;
        option_classes.push(klass);
      }
      control = $('.mass-control', tiers);
      control.append(select.clone());
      newSelect = $('select[name=status]', control);
      newSelect.prepend($('<option>', {
        value: '-',
        selected: 'selected'
      }).text('## Cascade Status Change ##'));
      return $('select', control).change(function(event) {
        var forms, target;
        target = $(event.target);
        if (target.val() === '-') {
          return false;
        }
        tiers = target.closest('.tiers');
        forms = $('.tier-control', tiers);
        return forms.each(function(i, hform) {
          var form, status;
          form = $(hform);
          status = target.val();
          return $.ajax({
            type: 'POST',
            url: '/tiers/set_status',
            data: {
              agent: $('.name', form).text(),
              queue: $('input[name=queue]', form).val(),
              status: status
            },
            success: function() {
              var form_classes;
              form_classes = form.attr('class').split(/\s+/);
              $.each(form_classes, function(fc, klass) {
                if ($.inArray(klass, option_classes) >= 0) {
                  return form.removeClass(klass);
                }
              });
              form.addClass(status_classes[status]);
              return $('select[name=status]', form).val(status);
            }
          });
        });
      });
    });
  });
}).call(this);
