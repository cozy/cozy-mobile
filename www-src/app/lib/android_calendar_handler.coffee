log = require('./persistent_log')
    prefix: "AndroidCalendarHandler"
    date: true
androidCalendarHelper = require '../lib/android_calendar_helper'

module.exports = class AndroidCalendarHandler

    ACCOUNT:
        accountType: 'io.cozy'
        accountName: 'myCozy'

    getAll: (callback) ->
        log.info "getAll"

        navigator.calendarsync.allCalendars @ACCOUNT, (err, calendars) =>
            return callback err if err

            callback null, calendars

    get: (calendarName, callback) ->
        log.info "get"

        @getAll (err, calendars) =>
            return callback err if err

            for calendar in calendars
                if calendar.calendar_displayName is calendarName
                    return callback null, calendar

            callback new Error "No calendar found with '#{calendarName}' name."

    create: (doc, callback) ->
        log.info "change"

    update: (doc, callback) ->
        log.info "update"

    delete: (doc, callback) ->
        log.info "delete"
