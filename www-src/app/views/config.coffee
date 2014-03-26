BaseView = require '../lib/base_view'

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

        config =
            cozyURL: url
            password: pass
            deviceName: device

        app.replicator.registerRemote config, (err) =>
            return @displayError err.message if err

            $('#footer').text 'begin replication'

            app.replicator.replicateToLocalOneShotNoDeleted (err) =>
                return @displayError err.message if err

                $('#footer').text 'replication complete'
                app.router.navigate 'folder/', trigger: true


    displayError: (text, field) ->
        @error.remove() if @error
        @error = $('<div>').addClass('button button-full button-energized')
        @error.text text
        @$(field or '#btn-save').before @error


