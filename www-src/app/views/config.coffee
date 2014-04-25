BaseView = require '../lib/base_view'
showLoader = require './loader'
urlparse = require '../lib/url'

module.exports = class ConfigView extends BaseView

    className: 'list'
    template: require '../templates/config'

    events: ->
        'click #btn-save': 'doSave'

    doSave: ->

        url = @$('#input-url').val()
        pass = @$('#input-pass').val()
        device = @$('#input-device').val()

        unless url and pass and device
            return @displayError 'all fields are required'

        if url[0..3] is 'http'
            @$('#input-url').val url = urlparse(url).hostname

        config =
            cozyURL: url
            password: pass
            deviceName: device

        app.replicator.registerRemote config, (err) =>
            return @displayError err.message if err

            loader = showLoader """
                dowloading file structure
                (this may take a while, do not turn off the application)
            """

            progressback = (ratio) ->
                loader.setContent 'status = ' + 100*ratio + '%'

            app.replicator.initialReplication progressback, (err) =>
                loader.hide()
                return @displayError err.message if err

                $('#footer').text 'replication complete'
                app.router.navigate 'folder/', trigger: true


    displayError: (text, field) ->
        @error.remove() if @error
        text = 'Connection faillure' if ~text.indexOf('CORS request rejected')
        @error = $('<div>').addClass('button button-full button-energized')
        @error.text text
        @$(field or '#btn-save').before @error


