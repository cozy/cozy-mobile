log = require('./persistent_log')
    prefix: 'ConnectionHandler'
    date: true


instance = null


module.exports = class ConnectionHandler


    constructor:  ->
        return instance if instance
        instance = @
        @connected = navigator.connection.type isnt Connection.NONE
        log.debug @connected
        document.addEventListener 'offline', @_offline, false
        document.addEventListener 'online', @_online, false


    _online: ->
        unless @connected
            @connected = true
            log.debug 'online'
            app.init.startRealtime() if app.init.currentState is 'nRealtime'


    _offline: ->
        if @connected
            log.debug 'offline'
            @connected = false
            app.init.stopRealtime() if app.init.currentState is 'nRealtime'


    isConnected: ->
        log.debug "isConnected: #{@connected}"

        @connected
