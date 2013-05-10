$ ->
  unloadConfirm = (url, instanceId) ->
    unloadConfirmation = confirm('Navigating away will spin down the instance and you will have to start over. Continue?')
    if unloadConfirmation
      $.ajax
        url: "/cancel_instance"
        data: "instance_id=#{instanceId}"
        type: "POST"

      window.location.href = url

  closeHandler = ->
    $('.back_to_gerrit').bind 'click', (e) ->
      e.preventDefault()
      window.location.href = $('.gerrit_link').attr('href')

  disableActionButtons = (selector) ->
    selector = '.modal-footer .btn' if typeof selector == 'undefined'
    $(selector).attr('disabled', 'disabled').addClass('disabled')

  $('#magic_modal').modal
    keyboard: false,
    backdrop: 'static'
    closeHandler()

  $('#generate_button').bind 'click', (e) ->
    e.preventDefault()
    $('.error-box').hide()
    disableActionButtons()
    $('#generation_form').submit()
    $(@).html('Requesting Instance...')

  $('#spin_up_canvas').bind 'click', (e) ->
    e.preventDefault()
    disableActionButtons('.load-hide')
    $('.modal-body .label-info').hide()
    $('#canvas_form').hide()
    $('#loading-container').show()
    $('#confirmation_header').html('Loading Environment...')
    $('#game_button').show()
    $('#canvas_form').submit()

  $('#spin_up_cancel').bind 'click', (e) ->
    e.preventDefault()
    answer = confirm("Canceling will take you back to gerrit, proceed?")
    if answer
      $(@).html('Canceling...')
      disableActionButtons()
      $.post "/cancel_instance?instance_id=#{$('input[name=instance_id]').val()}", (data) ->
        window.location.href = $('.gerrit_link').attr('href')

  $('#game_hide').bind 'click', (e) ->
    e.preventDefault()
    $('#magic_modal').modal('show')
    $('#game_modal').modal('hide')

  $('#game_button').bind 'click', (e) ->
    e.preventDefault()
    $('#magic_modal').modal('hide')
    $('#game_modal').modal()

  $('#spin_error').bind 'click', (e) ->
    e.preventDefault()
    $errorLogHolder = $('#error_log_holder')
    if $(@).html() == 'See Server Log'
      $.get "/error_log?instance_ip=#{$('#spin_error_instance_ip').val()}", (data) ->
        $errorLogHolder.text(data)
      $('#generation_form').hide()
      $(@).html('Hide Server Log')
      $errorLogHolder.show()
    else
      $errorLogHolder.hide()
      $('#generation_form').show()
      $(@).html('See Server Log')
