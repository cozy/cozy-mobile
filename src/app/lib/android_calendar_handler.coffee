AndroidAccount = require "../replicator/fromDevice/android_account"
CozyToAndroidCalendar = require \
        "../replicator/transformer/cozy_to_android_calendar"
DesignDocuments = require "../replicator/design_documents"
log = require("./persistent_log")
    prefix: "AndroidCalendarHandler"
    date: true

androidCalendarsCache = null

module.exports = class AndroidCalendarHandler

    constructor: (@db, @calendarSync) ->
        @db ?= window.app.init.database.replicateDb
        @cozyToAndroidCalendar = new CozyToAndroidCalendar()
        @calendarSync ?= navigator.calendarsync

    _getAll: (callback) ->
        log.debug "_getAll"

        return callback null, androidCalendarsCache if androidCalendarsCache

        @calendarSync.allCalendars AndroidAccount.ACCOUNT, \
                (err, calendars) ->
            return callback err if err

            androidCalendarsCache = calendars
            callback null, calendars

    _getByName: (calendarName, callback) ->
        log.debug "_getByName"

        @_getAll (err, calendars) ->
            return callback err if err

            for calendar in calendars
                if calendar.calendar_displayName is calendarName
                    return callback null, calendar

            callback new Error "No calendar found with '#{calendarName}' name."

    getById: (calendarId, callback) ->
        log.debug "getById"

        @_getAll (err, calendars) ->
            return callback err if err

            for calendar in calendars
                if calendar._id.toString() is calendarId.toString()
                    return callback null, calendar

            callback new Error "Calendar isn't find with id:#{calendarId}"

    getOrCreate: (calendarName, callback) ->
        log.debug "getOrCreate"

        @_getByName calendarName, (err, calendar) =>
            if err
                @_create calendarName, callback
            else
                callback null, calendar

    _create: (calendarName, callback) ->
        log.debug "_create"

        @_getCalendarFromCozy calendarName, (err, cozyCalendar) =>
            return callback err if err

            androidCalendar = @cozyToAndroidCalendar.transform cozyCalendar, \
                    AndroidAccount.ACCOUNT
            @calendarSync.addCalendar androidCalendar, (err, calendarId) =>
                return callback err if err

                # add new calendar in cache
                androidCalendar._id = calendarId
                androidCalendarsCache ?= []
                androidCalendarsCache.push androidCalendar

                @getById calendarId, (err, calendar) ->
                    callback err, calendar

    update: (androidCalendar, callback) ->
        log.debug "update"

        @calendarSync.updateCalendar androidCalendar, \
                AndroidAccount.ACCOUNT, (err) ->
            return callback err if err

            # update cache
            for calendar, key in androidCalendarsCache
                if calendar?._id is androidCalendar._id
                    androidCalendarsCache[key] = androidCalendar

            callback null, true

    _delete: (androidCalendar, callback) ->
        log.debug "_delete"

        @calendarSync.deleteCalendar androidCalendar, \
                AndroidAccount.ACCOUNT, (err, deletedCount) ->
            return callback err if err

            # delete cache
            for calendar, key in androidCalendarsCache
                if calendar?._id is androidCalendar._id
                    androidCalendarsCache.splice(key, 1)

            callback null, true

    deleteIfEmpty: (androidCalendar, callback) ->
        log.debug "deleteIfEmpty"

        @db.query DesignDocuments.CALENDARS
        ,
            key: androidCalendar.name
            limit: 1
        , (err, res) =>
            return callback err if err

            if res.rows.length is 0 and res.total_rows is 0
                log.info "Delete android calendar: '#{androidCalendar.name}'"
                log.debug res
                @_delete androidCalendar, callback
            else
                callback()

    deleteIfEmptyById: (androidCalendarId, callback) ->
        log.debug "deleteIfEmptyById"

        @getById androidCalendarId, (err, androidCalendar) =>
            return callback err if err

            @deleteIfEmpty androidCalendar, callback




    _getCalendarFromCozy: (calendarName, callback) ->
        options =
            method: 'post'
            path: '/request/tag/byname/'
            type: 'data-system'
            body:
                include_docs: true
                key: calendarName
        requestCozy = window.app.init.requestCozy
        requestCozy.request options, (err, res, body) ->
            return callback err if err
            # No tag found, put a default color.
            calendar = body[0]?.doc or { name: name , color: '#2979FF' }
            callback null, calendar
