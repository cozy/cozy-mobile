# intialize module which initialize global vars.
require '/lib/utils'

Replicator = require './replicator/main'
LayoutView = require './views/layout'
ServiceManager = require './service/service_manager'
Notifications = require '../views/notifications'

log = require('/lib/persistent_log')
    prefix: "application"
    date: true
    processusTag: "Application"

module.exports =

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

            Router = require 'router'
            @router = new Router()

            @replicator = new Replicator()
            @layout = new LayoutView()

            @replicator.init (err, config) =>
                if err
                    log.error err.message, err.stack
                    return alert err.message or err

                @notificationManager = new Notifications()
                @serviceManager = new ServiceManager()

                $('body').empty().append @layout.render().$el
                Backbone.history.start()

                if config.remote
                    app.regularStart()

                else
                    # App's first start
                    @router.navigate 'login', trigger: true

    regularStart: ->
        app.foreground = true

        document.addEventListener "resume", =>
            log.info "RESUME EVENT"
            app.foreground = true
            if app.backFromOpen
                app.backFromOpen = false
                app.replicator.startRealtime()
            else
                app.replicator.backup {}, (err) -> log.error err.message if err
        , false
        document.addEventListener "pause", =>
            log.info "PAUSE EVENT"
            app.foreground = false
            app.replicator.stopRealtime()

        , false
        document.addEventListener 'offline', ->
            DeviceStatus = require './lib/device_status'
            DeviceStatus.update()
        , false
        document.addEventListener 'online', ->
            DeviceStatus = require './lib/device_status'
            DeviceStatus.update()
            backup = () ->
                app.replicator.backup {}, (err) -> log.error err.message if err
                window.removeEventListener 'realtime:onChange', backup, false
            window.addEventListener 'realtime:onChange', backup, false
        , false

        @router.navigate 'folder/', trigger: true
        @router.once 'collectionfetched', =>
            app.replicator.backup {}, (err) -> log.error err.message if err
