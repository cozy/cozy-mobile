BaseView = require '../lib/base_view'

module.exports = class LoginView extends BaseView

    className: 'list'
    template: require '../templates/login'

    events: ->
        'click #btn-save': 'doSave'

    doSave: ->
        return null if @saving
        @saving = $('#btn-save').text()
        @error.remove() if @error

        url = @$('#input-url').val()
        pass = @$('#input-pass').val()
        device = @$('#input-device').val()

        # check all fields filled
        unless url and pass and device
            return @displayError 'all fields are required'

        # keep only the hostname
        if url[0..3] is 'http'
            url = url.replace('https://', '').replace('http://', '')
            @$('#input-url').val url

        # remove trailing slash
        if url[url.length-1] is '/'
            @$('#input-url').val url = url[..-2]

        config =
            cozyURL: url
            password: pass
            deviceName: device

        $('#btn-save').text 'registering ...'
        # register on cozy's server
        app.replicator.registerRemote config, (err) =>
            return @displayError t err.message if err

            onProgress = (percent) ->
                $('#btn-save').text 'downloading hierarchy ' + parseInt(percent * 100) + '%'

            # first replication to fetch hierarchy
            app.replicator.initialReplication onProgress, (err) =>
                console.log err.stack if err
                return @displayError t err.message if err

                $('#footer').text 'replication complete'
                app.isFirstRun = true
                app.router.navigate 'config', trigger: true


    displayError: (text, field) ->
        $('#btn-save').text @saving
        @saving = false
        @error.remove() if @error
        text = 'Connection faillure' if ~text.indexOf('CORS request rejected')
        @error = $('<div>').addClass('button button-full button-energized')
        @error.text text
        @$(field or '#btn-save').before @error


