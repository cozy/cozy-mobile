EventSynchronizer = require "./event_synchronizer"
log = require('../../lib/persistent_log')
    prefix: "ChangeSynchronizer"
    date: true

module.exports = class ChangeSynchronizer

    constructor: (@eventSynchronizer) ->
        @eventSynchronizer = new EventSynchronizer() unless @eventSynchronizer

    synchronize: ->
        @eventSynchronizer.synchronize()
