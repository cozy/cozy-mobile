BaseView = require '../layout/base_view'
FirstReplication = require '../../lib/first_replication'


module.exports = class CheckCredentials extends BaseView


    className: 'page'
    template: require '../../templates/onboarding/check_credentials'
    backExit: true


    initialize: (@password) ->
        @config ?= app.init.config
        @router ?= app.router
        @database ?= app.init.database
        @canRedirect = false
        @firstReplication = new FirstReplication()
        StatusBar.backgroundColorByHexString '#33A6FF'

        setTimeout =>
            @canRedirect = true
        , 1500

        cozyUrl = @config.get 'cozyURL'
        deviceName = @config.get 'deviceName'

        app.init.replicator.registerRemoteSafe cozyUrl, @password, deviceName, \
                (err, body) =>
            if err
                @goTo =>
                    @router.password err.message
            else
                @config.set 'state', 'deviceCreated'
                @config.set 'deviceName', body.login
                @config.set 'devicePassword', body.password
                @config.set 'devicePermissions', body.permissions
                @database.setRemoteDatabase @config.getCozyUrl()
                @goTo =>
                    @router.navigate '#permissions/files', trigger: true
                @firstReplication.addTask 'files', =>
                    @config.set 'state', 'syncCompleted'


    goTo: (callback) ->
        if @canRedirect
            return callback()

        setTimeout =>
            @goTo callback
        , 100
