log = require('../../lib/persistent_log')
    prefix: "CozyToAndroidCalendar"
    date: true

###*
 * CozyToAndroidCalendar transform a cozy calendar to a android calendar and
 * reverse transform an android calendar to a cozy calendar.
 *
 * @class CozyToAndroidCalendar
###
module.exports = class CozyToAndroidCalendar

    ###*
     * @param {Object} cozyCalendar - it's a cozy calendar
     * @param {Object} account - it's android account
     * @param {Object} androidCalendar - it's an android calendar (optional)
    ###
    transform: (cozyCalendar, account, androidCalendar = undefined) ->
        log.debug "transform"

        return {
            _id: if androidCalendar then androidCalendar._id else undefined
            account_name: account.accountName
            account_type: account.accountType
            ownerAccount: account.accountName
            name: cozyCalendar.name.replace /\s/g, ''
            calendar_displayName: cozyCalendar.name
            calendar_color: @_color2Android(cozyCalendar.color)
            # No specific needs (?)
            #calendar_timezone: null

            # http://developer.android.com/reference/android/provider/
            # CalendarContract.CalendarColumns.html#CALENDAR_ACCESS_LEVEL
            calendar_access_level: 700
            sync_events: 1
            # METHOD_ALERT, METHOD_EMAIL
            allowedReminders: "1,2"
            allowedAvailability: "0" # Deactivated.
            allowedAttendeeTypes: "0" # Deactivated.
        }

    reverseTransform: (androidCalendar) ->
        log.debug "reverseTransform"

        new Error "TODO"

    _color2Android: (color) ->
        if color[0] is '#'
            return parseInt color.replace(/[^0-9A-Fa-f]/g, ''), 16
        else if color[0] is 'r'
            rgb = color.match /(\d+)/g
            return rgb[0] * 256 * 256 + rgb[1] * 256 + rgb[2] * 1
