basic = require '../lib/basic'

module.exports = class ReplicatorConfig extends Backbone.Model
    constructor: (@replicator) ->
        super null
        @remote = null
    defaults: ->
        _id: 'localconfig'
        syncContacts: app.locale is 'digidisk'
        syncImages: true
        syncOnWifi: true
        cozyURL: t 'None'
        deviceName: t 'None'

    fetch: (callback) ->
        @replicator.db.get 'localconfig', (err, config) =>
            if config
                @set config
                @remote = @createRemotePouchInstance()

            callback null, this

    save: (changes, callback) ->
        @set changes
        @replicator.db.put @toJSON(), (err, res) =>
            return callback err if err
            return callback new Error('cant save config') unless res.ok
            @set _rev: res.rev
            @remote = @createRemotePouchInstance()
            callback? null, this

    makeUrl: (path) ->
        json: true
        auth: @get 'auth'
        url: 'https://' + @get('cozyURL') + '/cozy' + path

    makeFilterName: -> @get('deviceId') + '/filter'

    createRemotePouchInstance: ->
        # This is ugly because we extract a reference to
        # the host object to monkeypatch pouchdb#2517
        # @TODO clean up when fixed upstream
        # https://github.com/pouchdb/pouchdb/issues/2517
        new PouchDB
            name: @get 'fullRemoteURL'
            getHost: => @remoteHostObject =
                remote: true
                protocol: 'https'
                host: @get 'cozyURL'
                port: 443
                path: ''
                db: 'cozy'
                headers: Authorization: basic @get 'auth'