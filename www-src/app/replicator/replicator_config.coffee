APP_VERSION = "0.1.18"
PouchDB = require 'pouchdb'
request = require '../lib/request'

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

    getConfigFilter: ->
        compare = "doc.docType === 'file' or doc.docType === 'folder'"
        compare += " or doc.docType === 'contact'" if @get "syncContacts"
        compare += " or doc.docType === 'event'" if @get "syncCalendars"
        if @get "cozyNotifications"
            compare += " or (doc.docType === 'notification'"
            compare += " and doc.type === 'temporary')"

        filters:
            config: "function (doc) { return #{compare} }"

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
                callback null, this

        options = @makeDSUrl('/filters/config')
        options.body = @getConfigFilter()
        request.put options, (err, res, body) =>
            return callback err if err
            return callback body unless body.success or body._id
            callback null, this

    getScheme: ->
        # Monkey patch for browser debugging
        if window.isBrowserDebugging
            return 'http'
        else
            return 'https'

    getCozyUrl: ->
        "#{@getScheme()}://#{@get("deviceName")}:#{@get('devicePassword')}" +
            "@#{@get('cozyURL')}"

    makeDSUrl: (path) ->
        json: true
        auth: @get 'auth'
        url: "#{@getCozyUrl()}/ds-api#{path}"

    makeReplicationUrl: (path) ->
        json: true
        auth: @get 'auth'
        url: "#{@getCozyUrl()}/replication#{path}"

    makeFilterName: ->
        "#{@get('deviceId')}/filter"

    createRemotePouchInstance: ->
        new PouchDB
            name: "#{@getCozyUrl()}/replication"
            ajax: timeout: 55 * 1000 # Before the cozy's one.

    appVersion: ->
        APP_VERSION

    isNewVersion: ->
        return APP_VERSION isnt @get('appVersion')

    updateVersion: (callback) ->
        if @isNewVersion()
            @save appVersion: APP_VERSION, callback
        else
            callback()

    serializePermissions: (permissions) ->
        Object.keys(permissions).sort()

    hasPermissions: ->
        _.isEqual @get('devicePermissions'), @serializePermissions(@permissions)
