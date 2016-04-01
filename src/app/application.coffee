# intialize module which initialize global vars.
require './lib/utils'

LayoutView     = require './views/layout'
Init           = require './init'

log = require('./lib/persistent_log')
    prefix: "application"
    date: true
    processusTag: "Application"

module.exports =

    initialize: ->
        log.debug "initialize"

        @init = new Init @
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
            @init.trigger 'resume'
        , false

        document.addEventListener "pause", =>
            log.info "PAUSE EVENT"
            @init.trigger 'pause'
        , false


    exit: (err) ->
        log.debug "exit"

        if err
            log.error err
            msg = err.message or err
            msg += "\n #{t('error try restart')}"
            alert msg
        navigator.app.exitApp()

    addDeviceListener: ->
        log.debug "addDeviceListener"

        document.addEventListener 'deviceready', @initialize, false
