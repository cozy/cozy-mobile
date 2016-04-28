async = require 'async'

EventImporter = require "./event_importer"
ContactImporter = require './contact_importer'
log = require('../../lib/persistent_log')
    prefix: "ChangesImporter"
    date: true

module.exports = class ChangesImporter

    constructor: (@config, @eventImporter, @contactImporter) ->
        @config ?= app.init.config
        @eventImporter ?= new EventImporter()
        @contactImporter ?= new ContactImporter()


    synchronize: (callback) ->
        log.debug "synchronize"

        async.series [
            (cb) =>
                if @config.get('syncCalendars')
                    @eventImporter.synchronize cb
                else cb()

            (cb) =>
                if @config.get('syncContacts')
                    @contactImporter.synchronize cb
                else cb()

        ], callback
