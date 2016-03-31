APP_VERSION = "1.0.0"

log = require('../lib/persistent_log')
    prefix: "replicator_config"
    date: true

module.exports = class ReplicatorConfig extends Backbone.Model
    constructor: (@db) ->
        super null
        @remote = null

    getCozyUrl: ->
        "#{@get("deviceName")}:#{@get('devicePassword')}" +
            "@#{@get('cozyURL')}"
