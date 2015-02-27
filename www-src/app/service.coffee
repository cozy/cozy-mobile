Replicator = require './replicator/main'
LayoutView = require './views/layout'



module.exports = Service =

    initialize: ->
        console.log "Service - Initialize service."
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
                console.log "Service - Replicator inited"
                if err
                    console.log err, err.stack
                    return alert err.message or err

                if config.remote
                    notification = require('./views/notifications')
                    @notificationManager = new notification()

                    app.replicator.backup false, ->
                        # TODO: give some time to finish and close things.
                        setTimeout window.service.workDone, 5000


document.addEventListener 'deviceready', ->
    Service.initialize()
