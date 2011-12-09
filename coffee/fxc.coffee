p = ->
  window.console?.log?(arguments)

divmod = (num1, num2) ->
  [num1 / num2, num1 % num2]

formatTime = (totalMinutes) ->
  [hours, minutes] = divmod(totalMinutes, 60)
  sprintf("%02d:%02d", hours, minutes)

days = []

onTimeRangeSlide = (event, ui) ->
  updateTimeLabels(ui.values)

onDayRangeSlide = (event, ui) ->
  updateDayLabels(ui.values)

updateTimeLabels = (values) ->
  [from, to] = values
  $('#time-from').val(from)
  $('#time-to').val(to)
  $('#time-show').text(
    "#{formatTime(from)} - #{formatTime(to)}"
  )

updateDayLabels = (values) ->
  [from, to] = values
  $('#day-from').val(from)
  $('#day-to').val(to)
  $('#day-show').text(
    "#{days[from]} - #{days[to]}"
  )

$ ->
  fromMinutes = parseInt($('#time-from').val(), 10)
  toMinutes = parseInt($('#time-to').val(), 10)

  $('#timerange').slider(
    range: true,
    min: 0,
    max: 1440,
    step: 15,
    values: [fromMinutes, toMinutes],
    slide: onTimeRangeSlide
  )

  updateTimeLabels([fromMinutes, toMinutes])

  days = for name in ['mo', 'tu', 'we', 'th', 'fr', 'sa', 'su']
    $("input[name='#{name}']").val()

  fromDay = parseInt($('#day-from').val(), 10)
  toDay = parseInt($('#day-to').val(), 10)

  $('#dayrange').slider(
    range: true,
    min: 0,
    max: 6,
    step: 1,
    values: [fromDay, toDay],
    slide: onDayRangeSlide
  )

  updateDayLabels([fromDay, toDay])

  $('#add-tod-dialog').dialog(
    autoOpen: false,
    height: 400,
    width: 500,
    modal: true,
    buttons: {
      'Create TOD': ->
        $.post(
          '/fxc/user/add_route',
          {
            uid: $('#user-id').val(),
            from_minute: parseInt($('#time-from').val(), 10),
            to_minute: parseInt($('#time-to').val(), 10),
            from_wday: parseInt($('#day-from').val(), 10),
            to_wday: parseInt($('#day-to').val(), 10),
            target: $('#route-ext').val(),
          },
          success: (data, textStatus, jqXHR) =>
            p(this)
            p(arguments)
            $(this).dialog('close')
        )
      'Cancel': ->
        $(this).dialog('close')
    }
  )

  $('#add-tod').button().click ->
    $('#add-tod-dialog').dialog('open')

  $('.sortable').sortable(
    placeholder: 'ui-state-highlight',
    update: (event, ui) ->
      p event: event, ui: ui
      $.post(
        '/fxc/user/sort_route',
        {
          uid: $('#user-id').val(),
        },
        success: (data, textStatus, jqXHR) =>
          p(arguments)
      )
  )

  $('.sortable').disableSelection()
