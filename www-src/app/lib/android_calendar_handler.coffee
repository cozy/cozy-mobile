androidCalendarHelper = require "./android_calendar_helper"
CozyToAndroidCalendar = require \
        "../replicator/transformer/cozy_to_android_calendar"
DesignDocuments = require "../replicator/design_documents"
request = require "./request"
log = require("./persistent_log")
    prefix: "AndroidCalendarHandler"
    date: true

module.exports = class AndroidCalendarHandler

    ACCOUNT:
        accountType: 'io.cozy'
        accountName: 'myCozy'

    constructor: (@db, @config, @calendarSync) ->
        @db ?= app.replicator.db
        @config ?= app.replicator.config
        @cozyToAndroidCalendar = new CozyToAndroidCalendar()
        @calendarSync ?= navigator.calendarsync

    getAll: (callback) ->
        log.info "getAll"

        @calendarSync.allCalendars @ACCOUNT, (err, calendars) =>
            return callback err if err

            callback null, calendars

    getByName: (calendarName, callback) ->
        log.info "getByName"

        @getAll (err, calendars) =>
            return callback err if err

            for calendar in calendars
                if calendar.calendar_displayName is calendarName
                    return callback null, calendar

            callback new Error "No calendar found with '#{calendarName}' name."

    getById: (calendarId, callback) ->
        log.info "getById"

        @getAll (err, calendars) =>
            return callback err if err

            for calendar in calendars
                if calendar._id is calendarId
                    return callback null, calendar

            callback new Error "Calendar isn't find with id:#{calendarId}"

    getOrCreate: (calendarName, callback) ->
        log.info "getOrCreate"

        @getByName calendarName, (err, calendar) =>
            if err
                @create calendarName, callback
            else
                callback null, calendar

    create: (calendarName, callback) ->
        log.info "create"

        @_getCalendarFromCozy calendarName, (err, cozyCalendar) =>
            return callback err if err

            androidCalendar = @cozyToAndroidCalendar.transform cozyCalendar, \
                    @ACCOUNT
            # todo: addCalendar return calendar not only id
            @calendarSync.addCalendar androidCalendar, (err, calendarId) =>
                return callback err if err

                @getById calendarId, (err, calendar) =>
                    callback err, calendar


    update: (androidCalendar, callback) ->
        log.info "update"

        @calendarSync.updateCalendar androidCalendar, @ACCOUNT, (err) ->
            return callback err if err
            callback null, true

    delete: (androidCalendar, callback) ->
        log.info "delete"

        @calendarSync.deleteCalendar androidCalendar, @ACCOUNT, \
                (err, deletedCount) =>
            return callback err if err
            callback null, true

    deleteIfEmpty: (androidCalendar, callback) ->
        log.info "deleteIfEmpty"

        @db.query DesignDocuments.CALENDARS
        ,
            key: androidCalendar.name
            limit: 1
        , (err, res) =>
            return callback err if err

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
