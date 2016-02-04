AndroidAccount = require "../fromDevice/android_account"
AndroidCalendarHandler = require "../../lib/android_calendar_handler"
CozyToAndroidCalendar = require "../transformer/cozy_to_android_calendar"
log = require('../../lib/persistent_log')
    prefix: "ChangeTagHandler"
    date: true

###*
  * ChangeTagHandler Can only update color of calendar.
  * For now, calendar is only a tag, so we do it this hack.
  * Calendar is created when an event is created.
  * Calendar is removed when last event of calendar is removed
  *
  * @class ChangeEventHandler
###
module.exports = class ChangeTagHandler

    constructor: ->
        @androidCalendarHandler = new AndroidCalendarHandler()
        @cozyToAndroidCalendar = new CozyToAndroidCalendar()

    dispatch: (cozyCalendar) ->
        log.info "dispatch"

        @androidCalendarHandler.getByName cozyCalendar.name, \
                (err, androidCalendar) =>
            # if androidCalendar is not find, this tag is for another thing
            if androidCalendar
                calendar = @cozyToAndroidCalendar.transform cozyCalendar, \
                        AndroidAccount.ACCOUNT, androidCalendar
                if calendar.calendar_color isnt androidCalendar.calendar_color
                    @androidCalendarHandler.update calendar, (err) ->
                        log.error err if err
