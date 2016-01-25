# intialize module which initialize global vars.
require './lib/utils'

Replicator    = require '../replicator/main'
Notifications = require '../views/notifications'
DeviceStatus  = require '../lib/device_status'
Translation   = require '../lib/translation'
Init            = require './replicator/init'


log = require('./lib/persistent_log')
    prefix: "application"
    date: true
    processusTag: "BackgroundService"


# This service will be started in it's own browser instance by the
# JSBackgroundService. It take place of traditionnal application object, on the
# widnow.app field too. It's allow to re-use the application's code without
# changes.
# Be carreful with shared resources, between application and services, as they
# may run simultaneously (but in independant browsers).
module.exports = BackgroundService =

    initialize: ->

        @replicator = new Replicator()
        @translation = new Translation()

        # Pre-init with english locale in service
        @translation.setLocale value: 'en'
        window.t = @translation.getTranslate()

        @init = new Init()
        @init.startStateMachine()
        @init.trigger 'startService'


    postConfigInit: (callback) ->
        @replicator.updateLocaleFromCozy (err) =>
            # Service is useless offline, quit on error.
            return callback err if err

            DeviceStatus.initialize()
            if @replicator.config.get 'cozyNotifications'
                # Activate notifications handling
                @notificationManager = new Notifications()

            conf = @replicator.config.attributes
            # Display config to help remote debuging.
            log.info "Service #{conf.appVersion}--\
            sync_contacts:#{conf.syncContacts},\
            sync_calendars:#{conf.syncCalendars},\
            sync_images:#{conf.syncImages},\
            sync_on_wifi:#{conf.syncOnWifi},\
            cozy_notifications:#{conf.cozyNotifications}"

            callback()


    startMainActivity: (err)->
        log.error err
        # Start activity to initialize app
        # or update permissions
        JSBackgroundService.startMainActivity (err)->
            log.error err if err
            # Then shutdown service
            window.service.workDone()

    exit: (err) ->
        log.error err if err
        # give some time to finish and close things.
        setTimeout ->
            # call this javabinding directly on object to avoid
            # Error 'NPMethod called on non-NPObject'
            window.service.workDone()
        , 5 * 1000


    addDeviceListener: ->
        document.addEventListener 'deviceready', =>
            try
                @initialize()

            catch error
                log.error 'EXCEPTION SERVICE INITIALIZATION : ', error

            finally
                # "Watchdog" : in all cases, kill service after 10'
                setTimeout ->
                    # call this javabinding directly on object to avoid
                    # Error 'NPMethod called on non-NPObject'
                    window.service.workDone()
                , 10 * 60 * 1000
