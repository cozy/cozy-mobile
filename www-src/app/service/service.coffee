Replicator = require '../replicator/main'
Notifications = require '../views/notifications'

# This service will be started in it's own browser instance by the
# JSBackgroundService. It take place of traditionnal application object, on the
# widnow.app field too. It's allow to re-use the application's code without
# changes.
# Be carreful with shared resources, between application and services, as they
# may run simultaneously (but in independant browsers).
module.exports = Service =

    initialize: ->
        # "Watchdog" : in all cases, kill service after 10'
        setTimeout window.service.workDone, 10 * 60 * 1000

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
                    console.log err, err.stack
                    return window.service.workDone()

                if config.remote
                    if config.get 'cozyNotifications'
                        # Activate notifications handling
                        @notificationManager = new Notifications()

                    # Function which synchronizes pouch and delayed close.
                    syncNQuit = (err) ->
                        app.replicator.sync { background: true }, (err) ->
                            console.log err if err
                            # give some time to finish and close things.
                            setTimeout window.service.workDone, 5 * 1000

                    if config.get 'syncImages'
                        app.replicator.backup { background: true }, syncNQuit

                    else if config.get 'cozyNotifications'
                        syncNQuit()

                else
                    window.service.workDone()


document.addEventListener 'deviceready', ->
    Service.initialize()
