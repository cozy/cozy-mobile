basic = require '../lib/basic'

module.exports = class ReplicatorConfig extends Backbone.Model
    constructor: (@replicator) ->
        super null
    defaults: ->
        _id: 'localconfig'
        syncContacts: app.locale is 'digidisk'
        syncImages: true
        syncOnWifi: true
        cozyURL: ''
        deviceName: ''

    fetch: (callback) ->
        @replicator.db.get 'localconfig', (err, config) =>
            if config
                @set config

            callback null, this

    save: (changes, callback) ->
        @set changes
        @replicator.db.put @toJSON(), (err, res) =>
            return callback err if err
            return callback new Error('cant save config') unless res.ok
            @set _rev: res.rev
            callback? null, this

    makeUrl: (path) ->
        json: true
        auth: @get 'auth'
        url: 'https://' + @get('cozyURL') + '/cozy' + path

    makeFilterName: -> @get('deviceId') + '/filter'
