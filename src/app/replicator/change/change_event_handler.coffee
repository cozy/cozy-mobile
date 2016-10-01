AndroidAccount = require '../fromDevice/android_account'
AndroidCalendarHandler = require '../../lib/android_calendar_handler'
CozyToAndroidEvent = require '../transformer/cozy_to_android_event'
Permission = require '../../lib/permission'
log = require('../../lib/persistent_log')
    prefix: 'ChangeEventHandler'
    date: true


###*
 * ChangeEventHandler Can create, update or delete an event on your device
 *
 * @class ChangeEventHandler
###
module.exports = class ChangeEventHandler


    constructor: (@calendarSync, @timezone) ->
        @account = AndroidAccount.ACCOUNT
        @androidCalendarHandler = new AndroidCalendarHandler()
        @cozyToAndroidEvent = new CozyToAndroidEvent()
        @calendarSync ?= navigator.calendarsync
        @permission = new Permission()
        unless @timezone
            @timezone = 'Europe/Paris'
            successCB = (date) => @timezone = date.timezone
            errorCB = -> log.warn 'Error getting timezone'
            navigator.globalization.getDatePattern successCB, errorCB


    dispatch: (cozyEvent, callback) ->

        success = =>
            @calendarSync.eventBySyncId cozyEvent._id, (err, androidEvents) =>
                if androidEvents and androidEvents.length > 0
                    androidEvent = androidEvents[0]
                    if cozyEvent._deleted
                        @_delete cozyEvent, androidEvent, callback
                    else
                        @_update cozyEvent, androidEvent, callback
                else
                    # event may have already been deleted from device
                    # or event never been created
                    @_create cozyEvent, callback unless cozyEvent._deleted

        @permission.checkPermission 'calendars', success, callback


    _create: (cozyEvent, callback) ->
        log.info "create"

        unless cozyEvent?.tags?.length > 0
            return @_calendarNameError cozyEvent, callback

        calendarName = cozyEvent.tags[0]

        @androidCalendarHandler.getOrCreate calendarName, (err, calendar) =>
            return @_calendarGetError cozyEvent, err, callback if err

            androidEvent = @cozyToAndroidEvent.transform \
                    cozyEvent, calendar, @timezone

            @calendarSync.addEvent androidEvent, @account, (err) =>
                if err
                    msg = 'This event can\'t be created due to an error'
                    return @_error cozyEvent, err, msg, callback

                log.info 'An event was imported.'
                callback()


    _update: (cozyEvent, androidEvent, callback) ->
        log.info "update"

        unless cozyEvent?.tags?.length > 0
            return @_calendarNameError cozyEvent, callback

        calendarName = cozyEvent.tags[0]

        @androidCalendarHandler.getOrCreate calendarName, (err, calendar) =>
            return @_calendarGetError cozyEvent, err, callback if err

            # delete calendar in background
            if calendar._id isnt androidEvent.calendar_id
                @androidCalendarHandler.deleteIfEmptyById \
                        androidEvent.calendar_id, (err) ->
                    @_calendarDeleteError cozyEvent, err, null if err

            androidEvent = @cozyToAndroidEvent.transform \
                    cozyEvent, calendar, @timezone, androidEvent

            @calendarSync.updateEvent androidEvent, @account, (err) =>
                if err
                    msg = 'This event have an error to update it'
                    return @_error cozyEvent, err, msg, callback

                log.info 'An event was updated.'
                callback()


    _delete: (cozyEvent, androidEvent, callback) ->
        log.info "delete"

        @calendarSync.deleteEvent androidEvent, @account, (err, deletedCount) =>
            if err
                msg = 'This event can\'t be deleted due to an error'
                return @_error cozyEvent, err, msg, callback

            # delete calendar in background
            @androidCalendarHandler.deleteIfEmptyById \
                    androidEvent.calendar_id, (err) =>
                @_calendarDeleteError cozyEvent, err, null if err

            if deletedCount > 0
                log.info 'An event was deleted.'
            callback()


    _calendarGetError: (cozyEvent, err, callback) ->
        msg = 'This calendar have an error to get or create it'
        @_error cozyEvent, err, msg, callback


    _calendarNameError: (cozyEvent, callback) ->
        msg = 'This event have no calendar name'
        @_error cozyEvent, null, msg, callback


    _calendarDeleteError: (cozyEvent, err, callback) ->
        msg = 'This calendar can\'t be deleted due to an error'
        @_error cozyEvent, err, msg, callback


    _error: (cozyEvent, err, msg, callback) ->
        log.warn msg
        log.warn cozyEvent
        log.warn err if err
        callback() if callback
