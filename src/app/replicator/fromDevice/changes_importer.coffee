async = require 'async'

EventSynchronizer = require "./event_synchronizer"
ContactImporter = require './contact_importer'
log = require('../../lib/persistent_log')
    prefix: "ChangesImporter"
    date: true

module.exports = class ChangesImporter

    constructor: (@config, @eventSynchronizer, @contactImporter) ->
        @config ?= app.init.config
        @eventSynchronizer ?= new EventSynchronizer()
        @contactImporter ?= new ContactImporter()


    synchronize: (callback) ->
        log.debug "synchronize"

        async.series [
            (cb) =>
                if @config.get('syncCalendars')
                    @eventSynchronizer.synchronize cb
                else cb()

            (cb) =>
                if @config.get('syncContacts')
                    @contactImporter.synchronize cb
                else cb()

        ], callback
