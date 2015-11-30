# intialize module which initialize global vars.
require '/lib/utils'

Replicator = require './replicator/main'
LayoutView = require './views/layout'
ServiceManager = require './service/service_manager'
Notifications = require '../views/notifications'
DeviceStatus = require './lib/device_status'


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
                    log.error err
                    msg = err.message or err
                    msg += "\n #{t('error try restart')}"
                    alert msg
                    return navigator.app.exitApp()

                # Monkey patch for browser debugging
                unless window.isBrowserDebugging
                    @notificationManager = new Notifications()
                    @serviceManager = new ServiceManager()

                $('body').empty().append @layout.render().$el
                $('body').css 'background-color', 'white'
                Backbone.history.start()

                DeviceStatus.initialize()

                if config.remote
                    app.replicator.checkPlatformVersions (err) =>
                        if err
                            log.error err
                            alert err.message or err
                            return navigator.app.exitApp()

                        unless config.hasPermissions()
                            app.router.navigate 'permissions', trigger: true

                        else
                            # TODO : try to move to regular start.
                            unless @replicator.config.has('checkpointed')
                                log.info 'Launch first replication again.'
                                app.router.navigate 'first-sync', trigger: true
                            else
                                app.regularStart()


                else # no config.remote
                    # App's first start
                    app.isFirstRun = true
                    @router.navigate 'login', trigger: true


    regularStart: ->
        app.foreground = true
        conf = app.replicator.config.attributes
        # Display config to help remote debuging.
        log.info "Start v#{app.replicator.config.appVersion()}--\
        sync_contacts:#{conf.syncContacts},sync_images:#{conf.syncImages},\
        sync_on_wifi:#{conf.syncOnWifi},\
        cozy_notifications:#{conf.cozyNotifications}"

        document.addEventListener "resume", =>
            log.info "RESUME EVENT"
            app.foreground = true
            if app.backFromOpen
                app.backFromOpen = false
                app.replicator.startRealtime()
            else
                @serviceManager.isRunning (err, running) =>
                    return log.error err if err
                    if running
                        app.replicator.startRealtime()
                        log.info "No backup on resume, as service still running."
                    else
                        app.replicator.backup {}, (err) -> log.error err if err
        , false
        document.addEventListener "pause", =>
            log.info "PAUSE EVENT"
            app.foreground = false
            app.replicator.stopRealtime()

        , false
        document.addEventListener 'online', ->
            backup = () ->

                app.replicator.backup {}, (err) -> log.error err if err
                window.removeEventListener 'realtime:onChange', backup, false
            window.addEventListener 'realtime:onChange', backup, false
        , false

        @router.navigate 'folder/', trigger: true
        @router.once 'collectionfetched', =>
            app.replicator.backup {}, (err) -> log.error err if err
