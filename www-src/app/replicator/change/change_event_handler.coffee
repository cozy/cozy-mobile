AndroidCalendarHandler = require "../../lib/android_calendar_handler"
CozyToAndroidEvent = require "../transformer/cozy_to_android_event"
log = require('../../lib/persistent_log')
    prefix: "ChangeEventHandler"
    date: true

module.exports = class ChangeEventHandler

    constructor: ->
        @androidCalendarHandler = new AndroidCalendarHandler()
        @cozyToAndroidEvent = new CozyToAndroidEvent()

    change: (doc) ->
        log.info "change"

        if doc._rev.split('-')[0] is "1"
            @create doc
        else
            @update doc

    create: (cozyEvent) ->
        log.info "create"

        calendarName = cozyEvent.tags[0]
        @androidCalendarHandler.getOrCreeate calendarName, (err, calendar) =>
            return log.error err if err

            androidEvent = @cozyToAndroidEvent.transform cozyEvent, calendar
            navigator.calendarsync.addEvent androidEvent, \
                    @androidCalendarHandler.ACCOUNT, (err, res) ->
                log.error err if err

    update: (cozyEvent) ->
        log.info "update"

        navigator.calendarsync.eventBySyncId cozyEvent._id, \
                (err, androidEvents) =>
            # todo: create event if not exist
            return log.error err if err

            androidEvent = androidEvents[0]
            calendarName = cozyEvent.tags[0]
            @androidCalendarHandler.getOrCreeate calendarName, \
                    (err, calendar) =>
                return log.error err if err

                androidEvent = @cozyToAndroidEvent.transform cozyEvent, \
                        calendar, androidEvent
                navigator.calendarsync.updateEvent androidEvent, \
                        @androidCalendarHandler.ACCOUNT, (err, res) ->
                    return log.error err if err

    delete: (cozyEvent) ->
        log.info "delete"

        navigator.calendarsync.eventBySyncId cozyEvent._id, \
                (err, androidEvents) =>
            return log.error err if err

            androidEvent = androidEvents[0]
            navigator.calendarsync.deleteEvent androidEvent, \
                    @androidCalendarHandler.ACCOUNT, (err, res) =>
                log.error err if err
                @androidCalendarHandler.getAll (err, calendars) =>
                    log.error err if err

                    for calendar in calendars
                        if calendar._id is androidEvent.calendar_id
                            calendarToDelete = calendar

                    if calendarToDelete
                        @androidCalendarHandler.deleteIfEmpty calendarToDelete,\
                                (err) ->
                            log.error err if err
