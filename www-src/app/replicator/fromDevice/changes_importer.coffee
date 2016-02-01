EventSynchronizer = require "./event_synchronizer"
log = require('../../lib/persistent_log')
    prefix: "ChangesImporter"
    date: true

module.exports = class ChangesImporter

    constructor: (@eventSynchronizer) ->
        @eventSynchronizer ?= new EventSynchronizer()

    synchronize: ->
        @eventSynchronizer.synchronize()
