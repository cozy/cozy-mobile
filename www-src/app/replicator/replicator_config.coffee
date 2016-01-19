APP_VERSION = "0.1.19"
PouchDB = require 'pouchdb'
request = require '../lib/request'
FilterManager = require './filter_manager'

log = require('../lib/persistent_log')
    prefix: "replicator_config"
    date: true

module.exports = class ReplicatorConfig extends Backbone.Model
    constructor: (@db) ->
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
        log.info "fetch"

        @db.get '_local/appconfig', (err, config) =>
            if config
                @set config
                @remote = @createRemotePouchInstance()

            callback null, this

    save: (changes, callback) ->
        log.info "save changes"

        @set changes
        # Update _rev, if another process (service) has modified it since.
        @db.get '_local/appconfig', (err, config) =>
            unless err # may be 404, at doc initialization.
                @set _rev: config._rev

            doc = @toJSON()
            delete doc.password if doc.password

            @db.put doc, (err, res) =>
                return callback err if err
                return callback new Error('cant save config') unless res.ok
                @set _rev: res.rev
                @remote = @createRemotePouchInstance()
                if changes.syncContacts or changes.syncCalendars or \
                        changes.cozyNotifications or changes.deviceName
                    @setReplicationFilter (res) =>
                        callback null, this
                else
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

    hasPermissions: (permissions) ->
        _.isEqual \
            @get('devicePermissions'), \
            @serializePermissions(permissions)

    getFilterManager: ->
        unless @filterManager
            @filterManager = new FilterManager @getCozyUrl(), @get('auth'), \
                    @get("deviceName")
        @filterManager

    getReplicationFilter: ->
        log.info "getReplicationFilter"
        @getFilterManager().getFilterName()

    setReplicationFilter: (callback) ->
        log.info "setReplicationFilter"
        @getFilterManager().setFilter @get("syncContacts"), \
            @get("syncCalendars"), @get("cozyNotifications"), callback
