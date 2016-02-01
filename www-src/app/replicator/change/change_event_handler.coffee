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

    constructor: (@calendarSync) ->
        @androidCalendarHandler = new AndroidCalendarHandler()
        @cozyToAndroidEvent = new CozyToAndroidEvent()
        @calendarSync ?= navigator.calendarsync

    dispatch: (cozyEvent) ->
        log.info "dispatch"

        @calendarSync.eventBySyncId cozyEvent._id, (err, androidEvents) =>
            if androidEvents.length > 0
                androidEvent = androidEvents[0]
                if cozyEvent._deleted
                    @_delete cozyEvent, androidEvent
                else
                    @_update cozyEvent, androidEvent
            else
                # event may have already been deleted from device
                # or event never been created
                @_create cozyEvent unless cozyEvent._deleted

    _create: (cozyEvent) ->
        log.info "create"

        calendarName = cozyEvent.tags[0]
        @androidCalendarHandler.getOrCreate calendarName, (err, calendar) =>
            return log.error err if err

            androidEvent = @cozyToAndroidEvent.transform cozyEvent, calendar
            @calendarSync.addEvent androidEvent, \
                    AndroidCalendarHandler.ACCOUNT, (err, androidEventId) ->
                log.error err if err

    _update: (cozyEvent, androidEvent) ->
        log.info "update"

        calendarName = cozyEvent.tags[0]
        @androidCalendarHandler.getOrCreate calendarName, (err, calendar) =>
            return log.error err if err

            androidEvent = @cozyToAndroidEvent.transform cozyEvent, calendar, \
                    androidEvent
            @calendarSync.updateEvent androidEvent, \
                    AndroidCalendarHandler.ACCOUNT, (err) ->
                return log.error err if err

    _delete: (cozyEvent, androidEvent) ->
        log.info "delete"

        @calendarSync.deleteEvent androidEvent, \
                @androidCalendarHandler.ACCOUNT, (err, deletedCount) =>
            log.error err if err

            @androidCalendarHandler.getById androidEvent.calendar_id, \
                    (err, androidCalendar) =>
                log.error err if err

                @androidCalendarHandler.deleteIfEmpty androidCalendar, (err) ->
                    log.error err if err
