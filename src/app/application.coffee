# intialize module which initialize global vars.
require './lib/utils'
toast = require './lib/toast'
Initialize = require './lib/initialize'
Synchronization = require './lib/synchronization'
ServiceManager = require './models/service_manager'
log = require('./lib/persistent_log')
    prefix: "application"
    date: true
    processusTag: "Application"


module.exports =


    initialize: ->
        log.debug "initialize"

        @name = 'APP'
        @init = new Initialize @
        @init.initConfig =>
            Backbone.history.start()
            @startLayout()
            @startSynchronization()
            # The ServiceManager is a flag for the background plugin to
            # know if it's the service or the application,
            # see https://git.io/vVjJO
            @serviceManager = new ServiceManager()


    startLayout: ->
        log.debug "startLayout"

        Router = require './router'
        @router = new Router()
        @router.init @init.config.get 'state'


    startSynchronization: ->
        log.info 'startSynchronization'

        @synchro = new Synchronization()
        @synchro.sync()


    setListeners: ->
        log.debug "setListeners"

        document.addEventListener "resume", =>
            log.info "RESUME EVENT"
            @state = 'resume'
            @init.config.set 'appState', 'launch', =>
                @init.trigger 'resume'
        , false

        document.addEventListener "pause", =>
            log.info "PAUSE EVENT"
            toast.hide()
            @state = 'pause'
            @init.config.set 'appState', 'pause', =>
                @init.trigger 'pause'
        , false


    exit: (err) ->
        log.debug "exit"

        if err
            log.error err
            msg = err.message or err
            msg += "\n #{t('error try restart')}"
            navigator.notification.alert msg
        navigator.app.exitApp()


    addDeviceListener: ->
        log.debug "addDeviceListener"

        document.addEventListener 'deviceready', =>
            cordova.plugins.certificates.trustUnsecureCerts true
            window.open = cordova.InAppBrowser.open
            @initialize()
        , false
