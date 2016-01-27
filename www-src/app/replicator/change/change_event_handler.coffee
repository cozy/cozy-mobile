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
        @androidCalendarHandler.get calendarName, (err, calendar) =>
            # todo: create calendar when it's not present
            return log.error err if err

            androidEvent = @cozyToAndroidEvent.transform cozyEvent, calendar
            navigator.calendarsync.addEvent androidEvent, \
                    @androidCalendarHandler.ACCOUNT, (err, res) ->
                log.error err if err

    update: (doc) ->
        log.info "update"

        console.log doc

    delete: (doc) ->
        log.info "delete"

        console.log doc
