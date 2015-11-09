basic = require '../lib/basic'

APP_VERSION = "0.1.11"

module.exports = class ReplicatorConfig extends Backbone.Model
    constructor: (@replicator) ->
        super null
        @remote = null
    defaults: ->
        _id: 'localconfig'
        syncContacts: true
        syncImages: true
        syncOnWifi: true
        cozyNotifications: true
        cozyURL: ''
        deviceName: ''

    fetch: (callback) ->
        @replicator.db.get 'localconfig', (err, config) =>
            if config
                @set config
                @remote = @createRemotePouchInstance()

            callback null, this

    save: (changes, callback) ->
        @set changes
        # Update _rev, if another process (service) has modified it since.
        @replicator.db.get 'localconfig', (err, config) =>
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


    makeUrl: (path) ->
        json: true
        auth: @get 'auth'
        url: "#{@getScheme()}://" + @get('cozyURL') + '/cozy' + path

    makeFilterName: -> @get('deviceId') + '/filter'

    createRemotePouchInstance: ->
        new PouchDB
            name: @get 'fullRemoteURL'
            ajax: timeout: 5 * 60 * 1000 # Big timeout for unknown error on
                                         # longpoll

    appVersion: -> return APP_VERSION
