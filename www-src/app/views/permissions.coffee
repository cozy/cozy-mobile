BaseView = require '../lib/base_view'

log = require('/lib/persistent_log')
    prefix: "PermissionsView"
    date: true

module.exports = class PermissionsPickerView extends BaseView

    className: 'list'
    template: require '../templates/permissions'

    events: ->
        'click #btn-save': 'doNext'
        'click #btn-back': 'doBack'


    getRenderData: ->
        return permissions: app.replicator.permissions, firstRun: app.isFirstRun

    doBack: ->
        if app.isFirstRun
            app.router.navigate 'login', trigger: true
        else
            navigator.app.exitApp()

    doNext: ->
        if app.isFirstRun
           return app.router.navigate 'device-name-picker', trigger: true

        # else
        console.log 'truc'
        pass = @$('#input-pass').val()
        unless pass
            return @displayError t 'all fields are required'

        app.replicator.updatePermissions pass, (err) =>
            if err
                @displayError err
            else
                app.regularStart()


    displayError: (text, field) ->
        $('#btn-save').text @saving
        #TODO @saving = false # deactivate button on save.
        @error.remove() if @error
        @error = $('<div>').addClass('error-msg')
        @error.html text
        @$(field or '.button-bar').before @error
