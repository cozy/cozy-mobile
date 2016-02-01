AndroidCalendarHandler = require "../../lib/android_calendar_handler"
log = require("../../lib/persistent_log")
    prefix: "AndroidCalendarCache"
    date: true

module.exports = class AndroidCalendarCache

    constructor: (@androidCalendarHandler) ->
        @androidCalendarHandler ?= new AndroidCalendarHandler()

    getAll: (callback) ->
        log.info "getAll"

        if @androidCalendars
            callback null, @androidCalendars
        else
            @androidCalendarHandler.getAll (err, androidCalendars) =>
                return callback err if err
                @androidCalendars = androidCalendars
                callback null, @androidCalendars

    getById: (calendarId, callback) ->
        log.info "getById"

        @getAll (err, androidCalendars) =>
            return callback err if err

            for androidCalendar in androidCalendars
                if androidCalendar._id is calendarId
                    return callback null, androidCalendar

            callback new Error "Calendar isn't find with id:#{calendarId}"
