APP_VERSION = "0.1.14"

module.exports = class ReplicatorConfig extends Backbone.Model
    constructor: (@replicator) ->
        super null
        @remote = null

    defaults: ->
        _id: '_local/appconfig'
        syncContacts: true
        syncCalendars: true
        syncImages: true
        syncOnWifi: true
        cozyNotifications: false
        cozyURL: ''
        deviceName: ''

    fetch: (callback) ->
        @replicator.db.get '_local/appconfig', (err, config) =>
            if config
                @set config
                @remote = @createRemotePouchInstance()

            callback null, this

    save: (changes, callback) ->
        @set changes
        # Update _rev, if another process (service) has modified it since.
        @replicator.db.get '_local/appconfig', (err, config) =>
            unless err # may be 404, at doc initialization.
                @set _rev: config._rev

            @replicator.db.put @toJSON(), (err, res) =>
                return callback err if err
                return callback new Error('cant save config') unless res.ok
                @set _rev: res.rev
                @remote = @createRemotePouchInstance()
                callback? null, this

    getScheme: () ->
        # Monkey patch for browser debugging
        if window.isBrowserDebugging
            return 'http'
        else
            return 'https'

    makeDSUrl: (path) ->
        json: true
        auth: @get 'auth'
        url: "#{@getScheme()}://#{@get("deviceName")}:#{@get('devicePassword')}" + "@#{@get('cozyURL')}/ds-api#{path}"

    makeReplicationUrl: (path) ->
        json: true
        auth: @get 'auth'
        url: "#{@getScheme()}://#{@get("deviceName")}:#{@get('devicePassword')}" + "@#{@get('cozyURL')}/replication#{path}"


    makeFilterName: -> "#{@get('deviceId')}/filter"

    createRemotePouchInstance: ->
        new PouchDB
            name: "#{@getScheme()}://#{@get("deviceName")}:" +
                "#{@get('devicePassword')}@#{@get('cozyURL')}/replication"
            ajax: timeout: 5 * 60 * 1000 # Big timeout for unknown error on
                                         # longpoll

    appVersion: -> return APP_VERSION

    isNewVersion: ->
        return APP_VERSION isnt @get('appVersion')

    updateVersion: (callback) ->
        if @isNewVersion()
            @save appVersion: APP_VERSION, callback
        else
            callback()

    serializePermissions: (permissions) ->
        return Object.keys(permissions).sort()

    hasPermissions: ->
        _.isEqual @get('devicePermissions'), @serializePermissions(@replicator.permissions)
