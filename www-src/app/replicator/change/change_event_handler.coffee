AndroidCalendarHandler = require "../../lib/android_calendar_handler"
CozyToAndroidEvent = require "../transformer/cozy_to_android_event"
log = require('../../lib/persistent_log')
    prefix: "ChangeEventHandler"
    date: true

module.exports = class ChangeEventHandler

    constructor: (@calendarSync) ->
        @androidCalendarHandler = new AndroidCalendarHandler()
        @cozyToAndroidEvent = new CozyToAndroidEvent()
        @calendarSync = navigator.calendarsync unless @calendarSync

    dispatch: (cozyEvent) ->
        log.info "dispatch"

        @calendarSync.eventBySyncId cozyEvent._id, (err, androidEvents) =>
            if androidEvents.length > 0
                androidEvent = androidEvents[0]
                if cozyEvent._deleted
                    @delete cozyEvent, androidEvent
                else
                    @update cozyEvent, androidEvent
            else
                @create cozyEvent unless cozyEvent._deleted

    create: (cozyEvent) ->
        log.info "create"

        calendarName = cozyEvent.tags[0]
        @androidCalendarHandler.getOrCreate calendarName, (err, calendar) =>
            return log.error err if err

            androidEvent = @cozyToAndroidEvent.transform cozyEvent, calendar
            @calendarSync.addEvent androidEvent, \
                    @androidCalendarHandler.ACCOUNT, (err, androidEventId) ->
                log.error err if err

    update: (cozyEvent, androidEvent = undefined) ->
        log.info "update"

        return @dispatch cozyEvent unless androidEvent

        calendarName = cozyEvent.tags[0]
        @androidCalendarHandler.getOrCreate calendarName, (err, calendar) =>
            return log.error err if err

            androidEvent = @cozyToAndroidEvent.transform cozyEvent, calendar, \
                    androidEvent
            @calendarSync.updateEvent androidEvent, \
                    @androidCalendarHandler.ACCOUNT, (err) ->
                return log.error err if err

    delete: (cozyEvent, androidEvent) ->
        log.info "delete"

        return @dispatch cozyEvent unless androidEvent

        @calendarSync.deleteEvent androidEvent, \
                @androidCalendarHandler.ACCOUNT, (err, deletedCount) =>
            log.error err if err

            @androidCalendarHandler.getById androidEvent.calendar_id, \
                    (err, androidCalendar) =>
                log.error err if err

                @androidCalendarHandler.deleteIfEmpty androidCalendar, (err) ->
                    log.error err if err
