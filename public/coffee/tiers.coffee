p = (obj) ->
  window.console?.debug?(obj)

$ ->
  root = $('.tiers_agents .tiers')
  root.each (i, tiers) ->
    select = $('select[name=status]', tiers).first()
    options = []
    $('option', select).each (i,o) ->
      options.push($(o).val())
    option_classes = []
    status_classes = {}
    for option in options
      klass = option.toLowerCase().
        replace(/\W+/g, "-").
        replace(/^-+|-+$/, "")
      status_classes[option] = klass
      option_classes.push(klass)
    control = $('.mass-control', tiers)
    control.append(select.clone())

    newSelect = $('select[name=status]', control)
    newSelect.prepend(
      $('<option>', value: '-', selected: 'selected').
      text('## Cascade Status Change ##')
    )

    $('select', control).change (event) ->
      target = $(event.target)
      return false if target.val() == '-'
      tiers = target.closest('.tiers')
      forms = $('.tier-control', tiers)
      forms.each (i, hform) ->
        form = $(hform)
        status = target.val()
        $.ajax(
          type: 'POST',
          url: '/tiers/set_status',
          data: {
            agent: $('.name', form).text()
            queue: $('input[name=queue]', form).val()
            status: status,
          },
          success: ->
            form_classes = form.attr('class').split(/\s+/)
            $.each form_classes, (fc, klass) ->
              if $.inArray(klass, option_classes) >= 0
                form.removeClass(klass)
            form.addClass(status_classes[status])
            $('select[name=status]', form).val(status)
        )
