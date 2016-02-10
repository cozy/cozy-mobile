APP_VERSION = "0.2.0"
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

    updateAndGetInitNeeds: (changes) ->
        needInit =
            notifications: changes.cozyNotifications and \
                (changes.cozyNotifications isnt @get('cozyNotifications'))
            calendars: changes.syncCalendars and \
                (changes.syncCalendars isnt @get('syncCalendars'))
            contacts: changes.syncContacts and \
                (changes.syncContacts isnt @get('syncContacts'))
            deviceName: changes.deviceName

        @set changes

        return needInit

    ###*
     *
     * @param changes [optional] object with attributes to changes
     * @param callback
    ###
    save: (changes, callback) ->
        log.info "save changes"
        if arguments.length is 2
            @set changes if changes?
        else if arguments.length is 1
            callback = changes

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

                callback null, @

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
        @filterManager ?= new FilterManager @

    getReplicationFilter: ->
        log.info "getReplicationFilter"
        @getFilterManager().getFilterName()

