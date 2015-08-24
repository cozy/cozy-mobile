# intialize module which initialize global vars.
require '/lib/utils'

Replicator = require '../replicator/main'
Notifications = require '../views/notifications'

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
                    log.error err.message, err.stack
                    return window.service.workDone()

                if config.remote

                    DeviceStatus = require '../lib/device_status'
                    document.addEventListener 'offline', ->
                        DeviceStatus.update()
                    , false

                    if config.get 'cozyNotifications'
                        # Activate notifications handling
                        @notificationManager = new Notifications()


                    delayedQuit = (err) ->
                        log.error err.message if err
                        # give some time to finish and close things.
                        setTimeout ->
                            # call this javabinding directly on object to avoid
                            # Error 'NPMethod called on non-NPObject'
                            window.service.workDone()
                        , 5 * 1000

                    app.replicator.backup { background: true }, (err) ->
                        if err
                            delayedQuit()
                        else
                            app.replicator.sync {background: true}, delayedQuit

                else
                    window.service.workDone()



document.addEventListener 'deviceready', ->
    try
        Service.initialize()

    catch error
        log.error 'EXCEPTION SERVICE INITIALIZATION : ', err.message

    finally
        # "Watchdog" : in all cases, kill service after 10'
        setTimeout ->
            # call this javabinding directly on object to avoid
            # Error 'NPMethod called on non-NPObject'
            window.service.workDone()
        , 10 * 60 * 1000
