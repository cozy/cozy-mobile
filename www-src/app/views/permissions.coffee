BaseView = require '../lib/base_view'

log = require('../lib/persistent_log')
    prefix: "PermissionsView"
    date: true

module.exports = class PermissionsPickerView extends BaseView

    className: 'list'
    template: require '../templates/permissions'

    events: ->
        'click #btn-save': 'doNext'
        'click #btn-back': 'doBack'

    getRenderData: ->
        return {
            permissions: app.replicator.permissions
            doesntNeedPassword: app.init.currentState is 'fPermissions'
        }

    doBack: -> app.init.trigger 'backClicked'

    doNext: ->
        if app.init.currentState is 'fPermissions'
            return app.init.trigger 'getPermissions'

        # else
        pass = @$('#input-pass').val()
        unless pass
            return @displayError t 'all fields are required'

        app.replicator.updatePermissions pass, (err) =>
            if err
                @displayError err
            else
                app.init.trigger 'getPermissions'


    displayError: (text, field) ->
        $('#btn-save').text @saving
        #TODO @saving = false # deactivate button on save.
        @error.remove() if @error
        @error = $('<div>').addClass('error-msg')
        @error.html text
        @$(field or '.button-bar').before @error
