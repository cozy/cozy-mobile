# intialize module which initialize global vars.
require './lib/utils'

Initialize = require './lib/initialize'
Synchronization = require './lib/synchronization'

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
        log.debug "initialize"

        @name = 'SERVICE'
        @init = new Initialize @
        @init.initConfig =>
            @startSynchronization()


    startSynchronization: ->
        log.info 'startSynchronization'

        @synchro = new Synchronization()
        syncLoop = false
        @synchro.sync syncLoop, =>
            @exit()


    startMainActivity: (err)->
        log.debug "startMainActivity"

        log.error err if err
        # Start activity to initialize app
        # or update permissions
        JSBackgroundService.startMainActivity (err)->
            log.error err if err
            # Then shutdown service
            window.service.workDone()

    exit: (err) ->
        log.debug "exit"

        log.error err if err
        # give some time to finish and close things.
        setTimeout ->
            # call this javabinding directly on object to avoid
            # Error 'NPMethod called on non-NPObject'
            window.service.workDone()
        , 5 * 1000


    addDeviceListener: ->
        log.debug "addDeviceListener"

        document.addEventListener 'deviceready', =>
            try
                @initialize()

            catch error
                log.error 'EXCEPTION SERVICE INITIALIZATION : ', error

            finally
                # "Watchdog" : in all cases, kill service after 14'
                setTimeout ->
                    # call this javabinding directly on object to avoid
                    # Error 'NPMethod called on non-NPObject'
                    window.service.workDone()
                , 14 * 60 * 1000
