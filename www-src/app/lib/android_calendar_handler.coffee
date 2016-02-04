AndroidAccount = require "../replicator/fromDevice/android_account"
androidCalendarHelper = require "./android_calendar_helper"
CozyToAndroidCalendar = require \
        "../replicator/transformer/cozy_to_android_calendar"
DesignDocuments = require "../replicator/design_documents"
request = require "./request"
log = require("./persistent_log")
    prefix: "AndroidCalendarHandler"
    date: true

androidCalendarsCache = null

module.exports = class AndroidCalendarHandler

    constructor: (@db, @config, @calendarSync) ->
        @db ?= app.replicator.db
        @config ?= app.replicator.config
        @cozyToAndroidCalendar = new CozyToAndroidCalendar()
        @calendarSync ?= navigator.calendarsync

    _getAll: (callback) ->
        log.info "_getAll"

        return callback null, androidCalendarsCache if androidCalendarsCache

        @calendarSync.allCalendars AndroidAccount.ACCOUNT, \
                (err, calendars) ->
            return callback err if err

            androidCalendarsCache = calendars
            callback null, calendars

    _getByName: (calendarName, callback) ->
        log.info "_getByName"

        @_getAll (err, calendars) ->
            return callback err if err

            for calendar in calendars
                if calendar.calendar_displayName is calendarName
                    return callback null, calendar

            callback new Error "No calendar found with '#{calendarName}' name."

    getById: (calendarId, callback) ->
        log.info "getById"

        @_getAll (err, calendars) ->
            return callback err if err

            for calendar in calendars
                if calendar._id is calendarId
                    return callback null, calendar

            callback new Error "Calendar isn't find with id:#{calendarId}"

    getOrCreate: (calendarName, callback) ->
        log.info "getOrCreate"

        @_getByName calendarName, (err, calendar) =>
            if err
                @_create calendarName, callback
            else
                callback null, calendar

    _create: (calendarName, callback) ->
        log.info "_create"

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
        log.info "update"

        @calendarSync.updateCalendar androidCalendar, \
                AndroidAccount.ACCOUNT, (err) ->
            return callback err if err

            # update cache
            for key, calendar in androidCalendarsCache
                if calendar._id is androidCalendar._id
                    androidCalendarsCache[key] = androidCalendar

            callback null, true

    _delete: (androidCalendar, callback) ->
        log.info "_delete"

        @calendarSync.deleteCalendar androidCalendar, \
                AndroidAccount.ACCOUNT, (err, deletedCount) ->
            return callback err if err

            # delete cache
            for key, calendar in androidCalendarsCache
                if calendar._id is androidCalendar._id
                    androidCalendarsCache.splice(key, 1)

            callback null, true

    deleteIfEmpty: (androidCalendar, callback) ->
        log.info "deleteIfEmpty"

        @db.query DesignDocuments.CALENDARS
        ,
            key: androidCalendar.name
            limit: 1
        , (err, res) =>
            return callback err if err

            @_delete androidCalendar, callback if res.rows.length is 0




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
