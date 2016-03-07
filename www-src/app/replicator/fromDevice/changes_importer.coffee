async = require 'async'
ContactImporter = require './contact_importer'
EventImporter = require './event_importer'
PictureImporter = require './picture_importer'
log = require('../../lib/persistent_log')
    prefix: "ChangesImporter"
    date: true

module.exports = class ChangesImporter

    constructor: (@config, @eventImporter, @contactImporter, @pictureImporter) \
            ->
        @config ?= app.replicator.config
        @eventImporter ?= new EventImporter()
        @contactImporter ?= new ContactImporter()
        @pictureImporter ?= new PictureImporter()


    synchronize: (callback) ->
        log.info "synchronize"

        async.series [
            (cb) =>
                if @config.get('syncCalendars')
                    @eventImporter.synchronize cb
                else cb()

            (cb) =>
                if @config.get('syncContacts')
                    @contactImporter.synchronize cb
                else cb()

            (cb) =>
                if @config.get('syncImages')
                    @pictureImporter.synchronize cb
                else cb()

        ], callback
