# intialize module which initialize global vars.
require './lib/utils'

Replicator     = require './replicator/main'
LayoutView     = require './views/layout'
ServiceManager = require './models/service_manager'
Notifications  = require './views/notifications'
DeviceStatus   = require './lib/device_status'
Translation    = require './lib/translation'
Init           = require './init'

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


    postConfigInit: (callback) ->
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
