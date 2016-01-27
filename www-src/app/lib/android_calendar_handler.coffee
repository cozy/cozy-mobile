androidCalendarHelper = require "./android_calendar_helper"
CozyToAndroidCalendar = require \
        "../replicator/transformer/cozy_to_android_calendar"
request = require "./request"
log = require("./persistent_log")
    prefix: "AndroidCalendarHandler"
    date: true

module.exports = class AndroidCalendarHandler

    ACCOUNT:
        accountType: 'io.cozy'
        accountName: 'myCozy'

    constructor: (@db = undefined, @config = undefined) ->
        @db = app.replicator.db unless @db
        @config = app.replicator.config unless @config
        @cozyToAndroidCalendar = new CozyToAndroidCalendar()

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

    getOrCreeate: (calendarName, callback) ->
        log.info "getOrCreeate"

        @get calendarName, (err, calendar) =>
            if err
                @create calendarName, callback
            else
                callback err, calendar

    create: (calendarName, callback) ->
        log.info "create"

        @_getCalendarFromCozy calendarName, (err, cozyCalendar) =>
            return callback err if err

            androidCalendar = @cozyToAndroidCalendar.transform cozyCalendar, \
                    @ACCOUNT
            navigator.calendarsync.addCalendar androidCalendar, \
                    (err, androidCalendarId) =>
                return callback err if err

                @get calendarName, (err, calendar) =>
                    callback err, calendar


    update: (doc, callback) ->
        log.info "update"

    delete: (androidCalendar, callback) ->
        log.info "delete"

        navigator.calendarsync.deleteCalendar androidCalendar, @ACCOUNT, \
                (err, deletedCount) =>
            callback err if err
            callback err, true

    deleteIfEmpty: (androidCalendar, callback) ->
        log.info "deleteIfEmpty"

        # todo: optimize this request with _design map
        @db.query (doc, emit) ->
            if doc.docType is 'event' and doc.tags[0] is androidCalendar.name
                emit doc.name
        , {limit: 1} , (err, res) =>
            callback err if err

            @delete androidCalendar, callback if res.rows.length is 0




    _getCalendarFromCozy: (calendarName, callback) ->
        options = @config.makeDSUrl '/request/tag/byname/'
        options.body =
            include_docs: true
            key: calendarName

        request.post options, (err, res, body) ->
            return callback err if err
            # No tag found, put a default color.
            calendar = body[0]?.doc or { name: name , color: '#2979FF' }
            callback null, calendar
