AndroidAccount = require "../fromDevice/android_account"
AndroidCalendarHandler = require "../../lib/android_calendar_handler"
CozyToAndroidEvent = require "../transformer/cozy_to_android_event"
log = require('../../lib/persistent_log')
    prefix: "ChangeEventHandler"
    date: true

###*
 * ChangeEventHandler Can create, update or delete an event on your device
 *
 * @class ChangeEventHandler
###
module.exports = class ChangeEventHandler

    constructor: (@calendarSync, @timezone) ->
        @androidCalendarHandler = new AndroidCalendarHandler()
        @cozyToAndroidEvent = new CozyToAndroidEvent()
        @calendarSync ?= navigator.calendarsync
        unless @timezone
            successCB = (date) => @timezone = date.timezone
            errorCB = -> log.warn "Error getting timezone"
            navigator.globalization.getDatePattern successCB, errorCB

    dispatch: (cozyEvent, callback) ->
        log.debug "dispatch"
        @calendarSync.eventBySyncId cozyEvent._id, (err, androidEvents) =>
            if androidEvents.length > 0
                androidEvent = androidEvents[0]
                if cozyEvent._deleted
                    @_delete cozyEvent, androidEvent, callback
                else
                    @_update cozyEvent, androidEvent, callback
            else
                # event may have already been deleted from device
                # or event never been created
                @_create cozyEvent, callback unless cozyEvent._deleted


    _create: (cozyEvent, callback) ->
        log.debug "_create"

        calendarName = cozyEvent.tags[0]
        @androidCalendarHandler.getOrCreate calendarName, (err, calendar) =>
            return callback err if err

            androidEvent = @cozyToAndroidEvent.transform cozyEvent, calendar, \
                @timezone
            @calendarSync.addEvent androidEvent, \
                    AndroidAccount.ACCOUNT, callback


    _update: (cozyEvent, androidEvent, callback) ->
        log.debug "_update"

        calendarName = cozyEvent.tags[0]
        @androidCalendarHandler.getOrCreate calendarName, (err, calendar) =>
            return callback err if err

            # delete calendar in background
            if calendar._id isnt androidEvent.calendar_id
                @androidCalendarHandler.deleteIfEmptyById \
                        androidEvent.calendar_id, (err) ->
                    log.error err if err

            androidEvent = @cozyToAndroidEvent.transform cozyEvent, calendar, \
                    @timezone, androidEvent
            @calendarSync.updateEvent androidEvent, \
                    AndroidAccount.ACCOUNT, callback


    _delete: (cozyEvent, androidEvent, callback) ->
        log.debug "_delete"

        @calendarSync.deleteEvent androidEvent, \
                AndroidAccount.ACCOUNT, (err, deletedCount) =>
            log.error err if err

            # delete calendar in background
            @androidCalendarHandler.deleteIfEmptyById \
                    androidEvent.calendar_id, (err) ->
                log.error err if err

            callback()
