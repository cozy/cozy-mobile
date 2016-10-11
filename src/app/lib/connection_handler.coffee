log = require('./persistent_log')
    prefix: 'ConnectionHandler'
    date: true
instance = null


module.exports = class ConnectionHandler


    constructor: (@ConnectionState) ->
        return instance if instance
        instance = @

        # Connection is from cordova-plugin-network-information
        @ConnectionState ?= Connection
        @connected = @_getConnected()

        log.info @connected

        document.addEventListener 'offline', @_offline, false
        document.addEventListener 'online', @_online, false


    _online: ->
        unless @connected
            log.info 'online'
            @connected = true


    _offline: ->
        if @connected
            log.info 'offline'
            @connected = false


    _getConnected: ->
        navigator.connection.type isnt @ConnectionState.NONE


    isConnected: ->
        connected = @_getConnected()
        if connected isnt @connected
            if connected
                @_online()
            else
                @_offline()

        @connected


    isWifi: ->
        @isConnected() and navigator.connection.type is @ConnectionState.WIFI
