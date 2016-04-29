AndroidAccount = require "../fromDevice/android_account"
ChangeEventHandler = require "../change/change_event_handler"
async = require 'async'
CozyToAndroidEvent = require "../transformer/cozy_to_android_event"
AndroidCalendarHandler = require "../../lib/android_calendar_handler"
log = require('../../lib/persistent_log')
    prefix: "EventImporter"
    date: true
continueOnError = require('../../lib/utils').continueOnError log

module.exports = class EventImporter

    constructor: (@db, @calendarSync) ->
        @db ?= app.init.database.replicateDb
        @calendarSync ?= navigator.calendarsync
        @cozyToAndroidEvent = new CozyToAndroidEvent()
        @androidCalendarHandler = new AndroidCalendarHandler()
        @changeEventHandler = new ChangeEventHandler()

    synchronize: (callback) ->
        log.debug "synchronize"

        @calendarSync.dirtyEvents AndroidAccount.ACCOUNT, \
                (err, androidEvents) =>
            return log.error err if err
            log.info "syncPhone2Pouch #{androidEvents.length} events."

            async.eachSeries androidEvents, (androidEvent, cb) =>
                @_change androidEvent, cb
            , callback

    _change: (androidEvent, callback) ->
        log.debug "_change"

        if androidEvent.deleted
            @_delete androidEvent, continueOnError callback
        else
            @androidCalendarHandler.getById androidEvent.calendar_id, \
                (err, androidCalendar) =>
                    return log.error err if err

                    if androidEvent._sync_id
                        @_update androidEvent, androidCalendar, \
                                continueOnError callback
                    else
                        @_create androidEvent, androidCalendar, \
                                continueOnError callback

    # Create a new contact in app's pouchDB from newly created phone contact.
    # @param phoneContact cordova contact format.
    # @param retry retry lighter update after a failed one.
    _create: (androidEvent, androidCalendar, callback) ->
        log.debug "_create"

        cozyEvent = @cozyToAndroidEvent.reverseTransform androidEvent, \
                androidCalendar

        @db.post cozyEvent, (err, response) =>
            return callback err if err

            androidEvent._sync_id = response.id
            androidEvent.sync_data2 = response.rev

            @calendarSync.undirtyEvent androidEvent, \
                    AndroidAccount.ACCOUNT, callback

    # Update event in pouchDB with specified event from phone.
    # @param androidEvent
    # @param retry retry lighter update after a failed one.
    _update: (androidEvent, androidCalendar, callback) ->
        log.debug "_update"

        @db.get androidEvent._sync_id, (err, cozyEvent) =>
            return callback err if err

            cozyEvent = @cozyToAndroidEvent.reverseTransform androidEvent, \
                    androidCalendar, cozyEvent

            @db.put cozyEvent, cozyEvent._id, cozyEvent._rev, (err, response) =>
                return callback err if err

                androidEvent.sync_data2 = response.rev
                androidEvent.sync_data5 = cozyEvent.lastModified

                @calendarSync.undirtyEvent androidEvent, \
                        AndroidAccount.ACCOUNT, callback


    # Delete the specified contact in app's pouchdb.
    # @param phoneContact cordova contact format.
    _delete: (androidEvent, callback) ->
        log.debug "_delete"

        cozyEvent =
            docType: 'event'
            _id: androidEvent._sync_id
            _rev: androidEvent.sync_data2
            _deleted: true

        @db.put cozyEvent, cozyEvent._id, cozyEvent._rev, (err, res) =>
            return callback err if err

            @changeEventHandler._delete cozyEvent, androidEvent, callback
