log = require('./persistent_log')
    prefix: 'ConnectionHandler'
    date: true
toast = require './toast'


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
            if app.init.currentState and app.init.currentState[0] is 'f'
                app.layout.onCloseErrorIndicator()
                app.init.trigger 'restart'


    _offline: ->
        if @connected
            log.debug 'offline'
            @connected = false
            app.init.stopRealtime() if app.init.currentState is 'nRealtime'
            if app.init.currentState and app.init.currentState[0] is 'f'
                toast.warn 'lost_connection_first_replication'


    isConnected: ->
        connected = navigator.connection.type isnt Connection.NONE
        if connected isnt @connected
            if connected
                @_online()
            else
                @_offline()

        log.debug "isConnected: #{@connected}"

        @connected


    isWifi: ->
        @connected and navigator.connection.type is Connection.WIFI
