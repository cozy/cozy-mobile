# intialize module which initialize global vars.
require './lib/utils'

Replicator     = require './replicator/main'
LayoutView     = require './views/layout'
ServiceManager = require './models/service_manager'
Notifications  = require './views/notifications'
DeviceStatus   = require './lib/device_status'
Translation    = require './lib/translation'
Init            = require './replicator/init'

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

        @init = new Init()
        @init.startStateMachine()
        @init.trigger 'startApplication'
        # Backbone.history.start()

        # # Monkey patch for browser debugging
        # if window.isBrowserDebugging
        #     window.navigator = window.navigator or {}
        #     window.navigator.globalization =
        #         window.navigator.globalization or {}
        #     window.navigator.globalization.getPreferredLanguage = (callback) =>
        #         callback value: @translation.DEFAULT_LANGUAGE

        # # Use the device's locale until we get the config document.
        # navigator.globalization.getPreferredLanguage (properties) =>
        #     @translation.setLocale(properties)
        #     window.t = @translation.getTranslate()

            # @replicator.init (err, config) =>
            #     if err
            #         log.error err
            #         msg = err.message or err
            #         msg += "\n #{t('error try restart')}"
            #         alert msg
            #         return navigator.app.exitApp()

                # # Monkey patch for browser debugging
                # unless window.isBrowserDebugging
                #     @notificationManager = new Notifications()
                #     @serviceManager = new ServiceManager()

                # $('body').empty().append @layout.render().$el
                # $('body').css 'background-color', 'white'

                # DeviceStatus.initialize()

                # if config.remote
                    # if config.has 'locale'
                        # @translation.setLocale value: config.get 'locale'

                    # if config.isNewVersion()
                    #     Init = require './replicator/init'
                    #     @init = new Init()
                    #     @init.startStateMachine()
                    #     @init.trigger 'newVersion'

                    # else
                    #     @regularStart()

                # else # no config.remote
                    # App's first start
                    # @isFirstRun = true # TODO !
                    # @router.navigate 'login', trigger: true



    regularStart: ->
        # Update version tag if we reach here
        unless @replicator.config.has('checkpointed')
            log.info 'Launch first replication again.'
            @router.navigate 'first-sync', trigger: true
            return

        # @replicator.updateLocaleFromCozy (err) =>
            # log.error err if err
            # Continue with default locale on error

            # @foreground = true
            # conf = @replicator.config.attributes
            # # Display config to help remote debuging.
            # log.info "Start v#{conf.appVersion}--\
            # sync_contacts:#{conf.syncContacts},\
            # sync_calendars:#{conf.syncCalendars},\
            # sync_images:#{conf.syncImages},\
            # sync_on_wifi:#{conf.syncOnWifi},\
            # cozy_notifications:#{conf.cozyNotifications}"

            # @setListeners()
            # @router.navigate 'folder/', trigger: true
            # @router.once 'collectionfetched', =>
            #     @replicator.backup {}, (err) -> log.error err if err


    setDeviceLocale: (callback) ->
        # Monkey patch for browser debugging
        if window.isBrowserDebugging
            window.navigator = window.navigator or {}
            window.navigator.globalization =
                window.navigator.globalization or {}
            window.navigator.globalization.getPreferredLanguage = (cb) =>
                cb value: @translation.DEFAULT_LANGUAGE

        # Use the device's locale until we get the config document.
        navigator.globalization.getPreferredLanguage (properties) =>
            @translation.setLocale(properties)
            window.t = @translation.getTranslate()
            callback()


    postConfigInit: (callback) ->
        @replicator.updateLocaleFromCozy (err) =>
            return callback err if err
            unless window.isBrowserDebugging # Monkey patch for browser debugging
                @notificationManager = new Notifications()
                @serviceManager = new ServiceManager()

            DeviceStatus.initialize()
            @foreground = true
            conf = @replicator.config.attributes
            # Display config to help remote debuging.
            log.info "Start v#{conf.appVersion}--\
            sync_contacts:#{conf.syncContacts},\
            sync_calendars:#{conf.syncCalendars},\
            sync_images:#{conf.syncImages},\
            sync_on_wifi:#{conf.syncOnWifi},\
            cozy_notifications:#{conf.cozyNotifications}"

            # @setListeners()
            callback()


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
