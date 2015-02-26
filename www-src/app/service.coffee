Replicator = require './replicator/main'
LayoutView = require './views/layout'



module.exports = Service =

    initialize: ->
        console.log "window.app is service."

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

            # Router = require 'router'
            # @router = new Router()



            @replicator = new Replicator()
            #@layout = new LayoutView()

            @replicator.init (err, config) =>
                if err
                    console.log err, err.stack
                    return alert err.message or err

                #$('body').empty().append @layout.render().$el
                #Backbone.history.start()

                if config.remote
                    #@router.navigate 'folder/', trigger: true
                    #@router.once 'collectionfetched', =>
                        ##app.replicator.startRealtime()

                        # TODO :
                        notification = require('./views/notifications')
                        @notificationManager = new notification()

                        app.replicator.backup false, ->
                            console.log "replication done"
                            setTimeout window.service.workDone, 5000

                        # ## Test notification
                        # console.log window.plugin.notification.local.add
                        #     id: "1" # A unique id of the notifiction
                        #     #date: new Date()# When popup the notification. (Date)
                        #     message: "Yééééééé" # The message that is displayed
                        #     title: "You knoww" # The title of the message
                        #     #repeat:  # Either 'secondly', 'minutely', 'hourly', 'daily', 'weekly', 'monthly' or 'yearly'
                        #     #badge: Number # Displays number badge to notification
                        #     #sound: String # A sound to be played
                        #     #json: String # Data to be passed through the notification
                        #     #autoCancel: Boolean # Setting this flag and the notification is automatically canceled when the user clicks it
                        #     #ongoing: Boolean # Prevent clearing of notification (Android only)


                        # document.addEventListener "resume", =>
                        #     console.log "RESUME EVENT"
                        #     if app.backFromOpen
                        #         app.backFromOpen = false
                        #     else
                        #         app.replicator.backup()
                        # , false
                        # document.addEventListener 'offline', ->
                        #     device_status = require './lib/device_status'
                        #     device_status.update()
                        # , false
                        # document.addEventListener 'online', ->
                        #     device_status = require './lib/device_status'
                        #     device_status.update()
                        #     backup = () ->
                        #         app.replicator.backup(true)
                        #         window.removeEventListener 'realtime:onChange', backup, false
                        #     window.addEventListener 'realtime:onChange', backup, false
                        # , false
                #else
                    #@router.navigate 'login', trigger: true

document.addEventListener 'deviceready', ->
    Service.initialize()
