# intialize module which initialize global vars.
require './lib/utils'

Replicator     = require './replicator/main'
LayoutView     = require './views/layout'
ServiceManager = require './models/service_manager'
Notifications  = require './views/notifications'
DeviceStatus   = require './lib/device_status'
Translation    = require './lib/translation'

log = require('./lib/persistent_log')
    prefix: "application"
    date: true
    processusTag: "Application"

module.exports =

    initialize: ->

        Router = require './router'
        @router = new Router()
        @replicator = new Replicator()
        @layout = new LayoutView()
        @translation = new Translation()

        # Monkey patch for browser debugging
        if window.isBrowserDebugging
            window.navigator = window.navigator or {}
            window.navigator.globalization =
                window.navigator.globalization or {}
            window.navigator.globalization.getPreferredLanguage = (callback) =>
                callback value: @translation.DEFAULT_LANGUAGE

        navigator.globalization.getPreferredLanguage (properties) =>
            @translation.setLocale(properties)
            window.t = @translation.getTranslate()

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
                    if config.isNewVersion()
                        @replicator.checkPlatformVersions (err) =>
                            if err
                                log.error err
                                alert err.message or err
                                return navigator.app.exitApp()

                            if config.hasPermissions()
                                @regularStart()
                            else
                                @router.navigate 'permissions', trigger: true
                    else
                        @regularStart()

                else # no config.remote
                    # App's first start
                    @isFirstRun = true
                    @router.navigate 'login', trigger: true

    checkForUpdates: ->
        @replicator.checkPlatformVersions (err) =>
            if err
                log.error err
                alert err.message or err
                return navigator.app.exitApp()

            if @replicator.config.hasPermissions()
                @regularStart()
            else
                @router.navigate 'permissions', trigger: true


    regularStart: ->
        # Update version tag if we reach here
        @replicator.config.updateVersion =>
            unless @replicator.config.has('checkpointed')
                log.info 'Launch first replication again.'
                @router.navigate 'first-sync', trigger: true
                return

            @foreground = true
            conf = @replicator.config.attributes
            # Display config to help remote debuging.
            log.info "Start v#{conf.appVersion}--\
            sync_contacts:#{conf.syncContacts},sync_images:#{conf.syncImages},\
            sync_on_wifi:#{conf.syncOnWifi},\
            cozy_notifications:#{conf.cozyNotifications}"

            @setListeners()
            @router.navigate 'folder/', trigger: true
            @router.once 'collectionfetched', =>
                @replicator.backup {}, (err) -> log.error err if err


    setListeners: ->
        document.addEventListener "resume", =>
            log.info "RESUME EVENT"
            @foreground = true
            if @backFromOpen
                @backFromOpen = false
                @replicator.startRealtime()
            else
                @serviceManager.isRunning (err, running) =>
                    return log.error err if err
                    if running
                        @replicator.startRealtime()
                        log.info "No backup on resume, as service still running"
                    else
                        @replicator.backup {}, (err) -> log.error err if err
        , false

        document.addEventListener "pause", =>
            log.info "PAUSE EVENT"
            @foreground = false
            @replicator.stopRealtime()
        , false

    addDeviceListener: ->
        document.addEventListener 'deviceready', =>
            @initialize()
