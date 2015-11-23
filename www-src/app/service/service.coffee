# intialize module which initialize global vars.
require '/lib/utils'

Replicator = require '../replicator/main'
Notifications = require '../views/notifications'
DeviceStatus = require '../lib/device_status'


log = require('/lib/persistent_log')
    prefix: "application"
    date: true
    processusTag: "Service"


# This service will be started in it's own browser instance by the
# JSBackgroundService. It take place of traditionnal application object, on the
# widnow.app field too. It's allow to re-use the application's code without
# changes.
# Be carreful with shared resources, between application and services, as they
# may run simultaneously (but in independant browsers).
module.exports = Service =

    initialize: ->
        window.app = this

        # Monkey patch for browser debugging
        if window.isBrowserDebugging
            window.navigator = window.navigator or {}
            window.navigator.globalization = window.navigator.globalization or {}
            window.navigator.globalization.getPreferredLanguage = (callback) -> callback value: 'fr-FR'

        navigator.globalization.getPreferredLanguage (properties) =>
            [@locale] = properties.value.split '-'

            @polyglot = new Polyglot()
            locales = try require 'locales/'+ @locale
            catch e then require 'locales/en'

            @polyglot.extend locales
            window.t = @polyglot.t.bind @polyglot


            @replicator = new Replicator()
            @replicator.init (err, config) =>
                if err
                    log.error err
                    return window.service.workDone()

                if config.remote and config.hasPermissions()
                    unless @replicator.config.has('checkpointed')
                        log.error new Error "Database not initialized"
                        return window.service.workDone()

                    DeviceStatus.initialize()

                    if config.get 'cozyNotifications'
                        # Activate notifications handling
                        @notificationManager = new Notifications()


                    delayedQuit = (err) ->
                        log.error err if err
                        # give some time to finish and close things.
                        setTimeout ->
                            # call this javabinding directly on object to avoid
                            # Error 'NPMethod called on non-NPObject'
                            window.service.workDone()
                        , 5 * 1000

                    app.replicator.backup { background: true }, (err) ->
                        if err
                            log.error "Error launching backup: ", err
                            delayedQuit()
                        else
                            app.replicator.sync {background: true}, delayedQuit

                else
                    # Start activity to initialize app
                    # or update permissions
                    JSBackgroundService.startMainActivity (err)->
                        log.error err if err
                        # Then shutdown service
                        window.service.workDone()


document.addEventListener 'deviceready', ->
    try
        Service.initialize()

    catch error
        log.error 'EXCEPTION SERVICE INITIALIZATION : ', error

    finally
        # "Watchdog" : in all cases, kill service after 10'
        setTimeout ->
            # call this javabinding directly on object to avoid
            # Error 'NPMethod called on non-NPObject'
            window.service.workDone()
        , 10 * 60 * 1000
