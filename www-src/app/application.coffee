# intialize module which initialize global vars.
require './lib/utils'

Replicator     = require './replicator/main'
LayoutView     = require './views/layout'
ServiceManager = require './models/service_manager'
Notifications  = require './views/notifications'
DeviceStatus   = require './lib/device_status'
Translation    = require './lib/translation'
Init           = require './replicator/init'

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
            if err
                # Continue on error, app can work offline.
                log.error "Continue on updateLocaleFromCozy error: #{err.msg}"

            unless window.isBrowserDebugging # Patch for browser debugging
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
            @init.trigger 'resume'
        , false

        document.addEventListener "pause", =>
            log.info "PAUSE EVENT"
            @init.trigger 'pause'
        , false


    exit: (err) ->
        if err
            log.error err
            msg = err.message or err
            msg += "\n #{t('error try restart')}"
            alert msg
        navigator.app.exitApp()

    addDeviceListener: ->
        document.addEventListener 'deviceready', =>
            @initialize()
