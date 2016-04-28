async = require 'async'

ContactImporter = require './contact_importer'
EventImporter = require "./event_importer"
NotificationImporter = require "./notification_importer"

log = require('../../lib/persistent_log')
    prefix: "ChangesImporter"
    date: true


module.exports = class ChangesImporter


    constructor: (@config, @eventImporter, @contactImporter, @notifImporter) ->
        @config ?= app.init.config
        @eventImporter ?= new EventImporter()
        @contactImporter ?= new ContactImporter()
        @notifImporter ?= new NotificationImporter()


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

            (cb) =>
                if @config.get('cozyNotifications')
                    @notifImporter.synchronize cb
                else cb()

        ], callback
