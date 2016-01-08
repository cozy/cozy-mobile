BaseView = require '../lib/base_view'

log = require('../lib/persistent_log')
    prefix: "DeviceNamePickerView"
    date: true

module.exports = class DeviceNamePickerView extends BaseView

    className: 'list'
    template: require '../templates/device_name_picker'

    events: ->
        'click #btn-save': 'doSave'
        'blur #input-device': 'onCompleteDefaultValue'
        'focus #input-device': 'onRemoveDefaultValue'
        'click #btn-back': 'doBack'
        'keypress #input-device': 'blurIfEnter'

    doBack: ->
        app.router.navigate 'login', trigger: true

    blurIfEnter: (e) ->
        @$('#input-device').blur() if e.keyCode is 13

    doSave: ->
        return null if @saving
        @saving = $('#btn-save').text()
        @error.remove() if @error


        device = @$('#input-device').val()

        unless device
            return @displayError t 'all fields are required'

        if device.match /[^\w\-]/ # ie not a-z, A-Z, 0-9 _ -
            return @displayError t "device name use only digits, letters, _, -"


        config = app.loginConfig
        config.deviceName = device

        $('#btn-save').text t 'registering...'
        app.replicator.registerRemote config, (err) =>
            if err?
                log.error err
                @displayError t err.message
            else
                app.replicator.checkPlatformVersions (err) =>
                    if err?
                        log.error err
                        return @displayError err.message

                    delete app.loginConfig
                    app.router.navigate 'config', trigger: true

    onCompleteDefaultValue: ->
        device = @$('#input-device').val()
        if device is ''
            @$('#input-device').val t('device name placeholder')

    onRemoveDefaultValue: ->
        device = @$('#input-device').val()
        if device is t('device name placeholder')
            @$('#input-device').val ''

    displayError: (text, field) ->
        $('#btn-save').text @saving
        @saving = false
        @error.remove() if @error
        if text.indexOf('CORS request rejected') isnt -1
            text = t 'connection failure'
        @error = $('<div>').addClass('error-msg')
        @error.text text
        @$(field or 'label').after @error
