async = require 'async'
CozyToAndroidEvent = require "../transformer/cozy_to_android_event"
AndroidCalendarCache = require "../cache/android_calendar_cache"
AndroidCalendarHandler = require "../../lib/android_calendar_handler"
log = require('../../lib/persistent_log')
    prefix: "EventSynchronizer"
    date: true
continueOnError = require('../../lib/utils').continueOnError log

module.exports = class EventSynchronizer

    constructor: (@db, @calendarSync) ->
        @db ?= app.replicator.config.db
        @calendarSync ?= navigator.calendarsync
        @androidCalendarHandler = new AndroidCalendarHandler()
        @cozyToAndroidEvent = new CozyToAndroidEvent()
        @androidCalendarCache = new AndroidCalendarCache()

    synchronize: ->
        log.info "synchronize"

        @calendarSync.dirtyEvents @androidCalendarHandler.ACCOUNT, \
                (err, androidEvents) =>
            return log.error err if err

            async.eachSeries androidEvents, (androidEvent, cb) =>
                @change androidEvent, cb

    change: (androidEvent, callback) ->
        log.info "change"

        if androidEvent.deleted
            @delete androidEvent, continueOnError callback
        else
            # ? androidEvent = ACH.filterOrganizerAttendee androidEvent, @androidCalendarHandler.ACCOUNT
            @androidCalendarCache.getById androidEvent.calendar_id, \
                (err, androidCalendar) =>
                    return log.error err if err

                    if androidEvent._sync_id
                        @update androidEvent, androidCalendar, continueOnError \
                                callback
                    else
                        @create androidEvent, androidCalendar, continueOnError \
                                callback

    # Create a new contact in app's pouchDB from newly created phone contact.
    # @param phoneContact cordova contact format.
    # @param retry retry lighter update after a failed one.
    create: (androidEvent, androidCalendar, callback) ->
        log.info "create"

        cozyEvent = @cozyToAndroidEvent.reverseTransform androidEvent, \
                androidCalendar

        @db.post cozyEvent, (err, response) =>
            return callback err if err

            androidEvent._sync_id = response.id
            androidEvent.sync_data2 = response.rev

            @calendarSync.undirtyEvent androidEvent, \
                    @androidCalendarHandler.ACCOUNT, callback

    # Update event in pouchDB with specified event from phone.
    # @param androidEvent
    # @param retry retry lighter update after a failed one.
    update: (androidEvent, androidCalendar, callback) ->
        log.info "update"

        @db.get androidEvent._sync_id, (err, cozyEvent) =>
            return callback err if err

            cozyEvent = @cozyToAndroidEvent.reverseTransform androidEvent, \
                    androidCalendar, cozyEvent

            @db.put cozyEvent, cozyEvent._id, cozyEvent._rev, (err, response) =>
                return callback err if err

                androidEvent.sync_data2 = response.rev
                androidEvent.sync_data5 = cozyEvent.lastModified

                @calendarSync.undirtyEvent androidEvent, \
                        @androidCalendarHandler.ACCOUNT, callback


    # Delete the specified contact in app's pouchdb.
    # @param phoneContact cordova contact format.
    delete: (androidEvent, callback) ->
        log.info "delete"

        toDelete =
            docType: 'event'
            _id: androidEvent._sync_id
            _rev: androidEvent.sync_data2
            _deleted: true

        @db.put toDelete, toDelete._id, toDelete._rev, (err, res) =>
            return callback err if err

            @calendarSync.deleteEvent androidEvent, \
                    @androidCalendarHandler.ACCOUNT, callback
