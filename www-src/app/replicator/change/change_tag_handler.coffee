AndroidCalendarHandler = require "../../lib/android_calendar_handler"
CozyToAndroidCalendar = require "../transformer/cozy_to_android_calendar"
log = require('../../lib/persistent_log')
    prefix: "ChangeTagHandler"
    date: true

module.exports = class ChangeTagHandler

    constructor: (@calendarSync) ->
        @androidCalendarHandler = new AndroidCalendarHandler()
        @cozyToAndroidCalendar = new CozyToAndroidCalendar()

    dispatch: (cozyTag) ->
        log.info "dispatch"

        @androidCalendarHandler.getByName cozyTag.name, \
                (err, androidCalendar) =>
            # if androidCalendar is not find, this tag is for another thing
            if androidCalendar
                newCalendar = @cozyToAndroidCalendar.transform cozyTag, \
                        @androidCalendarHandler.ACCOUNT, androidCalendar
                if newCalendar.calendar_color isnt \
                        androidCalendar.calendar_color
                    @androidCalendarHandler.update newCalendar, (err) ->
                        log.error err if err
