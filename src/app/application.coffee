# intialize module which initialize global vars.
require './lib/utils'
toast = require './lib/toast'

LayoutView     = require './views/layout'
Init           = require './init'

log = require('./lib/persistent_log')
    prefix: "application"
    date: true
    processusTag: "Application"

module.exports =

    initialize: ->
        log.debug "initialize"

        @name = 'APP'
        @init = new Init @
        @init.initConfig =>
            @init.startStateMachine()
            @init.trigger 'startApplication'

    startLayout: ->
        log.debug "startLayout"

        Router = require './router'
        @router = new Router()
        @layout = new LayoutView()

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
            window.open = cordova.InAppBrowser.open
            @initialize()
        , false
