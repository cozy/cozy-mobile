BaseView = require '../lib/base_view'

module.exports = class DeviceNamePickerView extends BaseView

    className: 'list'
    template: require '../templates/device_name_picker'

    events: ->
        'click #btn-save': 'doSave'
        'click #btn-back': 'doBack'

    doBack: ->
        app.router.navigate 'login', trigger: true

    doSave: ->
        return null if @saving
        @saving = $('#btn-save').text()
        @error.remove() if @error


        device = @$('#input-device').val()

        unless device
            return @displayError 'all fields are required'

        config = app.loginConfig
        config.deviceName = device

        $('#btn-save').text t 'registering...'
        app.replicator.registerRemote config, (err) =>
            if err?
                @displayError err.message
            else
                delete app.loginConfig
                app.isFirstRun = true

                console.log 'starting first replication'
                noop = ->
                app.replicator.initialReplication noop

                app.router.navigate 'config', trigger: true

    displayError: (text, field) ->
        $('#btn-save').text @saving
        @saving = false
        @error.remove() if @error
        text = t 'connection failure' if ~text.indexOf('CORS request rejected')
        @error = $('<div>').addClass('button button-full button-energized')
        @error.text text
        @$(field or 'label').after @error