async = require 'async'
request = require '../lib/request'
ACH = require '../lib/android_calendar_helper'
DesignDocuments = require './design_documents'


# Account type and name of the created android contact account.
ACCOUNT_TYPE = 'io.cozy'
ACCOUNT_NAME = 'myCozy'

ACCOUNT =
    accountType: ACCOUNT_TYPE
    accountName: ACCOUNT_NAME

log = require('../lib/persistent_log')
    prefix: "calendars replicator"
    date: true


module.exports =
    # 'main' function for calendar synchronisation.
    syncCalendars: (callback) ->
        return callback null unless @config.get 'syncCalendars'

        @changesFromCozy = []

        # Feedback to the user.
        @set 'backup_step', 'calendar_sync'
        @set 'backup_step_done', null

        # Phone is right on conflict.
        # Calendar sync has 5 phases
        # 1 - Events initialisation (if necessary)
        # 2 - calendar update and fetching
        # 3 - sync Phone --> in app PouchDB
        # 4 - sync Cozy CouchDB --> in app PouchDB
        # 5 - fix conflicts keeping Cozy's versions
        # 6 - sync in app PouchDB --> Cozy couchDB
        # 7 - sync Cozy couchDB to phone (and app PouchDB)
        async.series [
            (cb) =>
                if @config.has('eventsPullCheckpointed')
                    cb()

                else
                    url = '/_changes?descending=true&limit=1'
                    request.get @config.makeReplicationUrl(url)
                    , (err, res, body) =>
                        return cb err if err
                        # we store last_seq before copying files & folder
                        # to avoid losing changes occuring during replication
                        @initEventsInPhone body.last_seq, cb
            (cb) => @updateCalendars cb
            (cb) => @syncEventsPhone2Pouch cb
            (cb) =>
                @set 'backup_step_done', null
                @set 'backup_step', 'events_sync_from_cozy'
                @syncEventsFromCozy cb
            (cb) =>
                async.eachSeries @changesFromCozy, (doc, cb2) =>
                    if doc._deleted
                        cb2()
                    else
                        @handleConflict doc, cb2
                , cb
            (cb) =>
                @set 'backup_step', 'events_sync_to_cozy'
                @syncEventsToCozy cb
            (cb) =>
                @set 'backup_step', 'events_sync_to_phone'
                @set 'backup_step_done', 0
                @set 'backup_step_total', @changesFromCozy.length
                @_applyEventsChangeToPhone @changesFromCozy, cb
        ], (err) ->
            log.info "Sync calendars done"
            @changesFromCozy = []
            callback err


    _getCalendarFromCozy: (name, callback) ->
        options = @config.makeDSUrl '/request/tag/byname/'
        options.body =
            include_docs: true
            key: name

        request.post options, (err, res, body) ->
            return callback err if err # TODO : pass on 404
            # No tag found, put a default color.
            calendar = body[0]?.doc or { name: name , color: '#2979FF' }
            callback null, calendar


    updateCalendars: (callback) ->
        navigator.calendarsync.allCalendars ACCOUNT, (err, calendars) =>
            return callback err if err

            @calendarIds = {}
            for calendar in calendars
                @calendarIds[calendar.calendar_displayName] = calendar._id

            @calendarNames = _.invert @calendarIds

            # Check calendars updates in cozy (ie tags colors update)
            async.eachSeries calendars, (calendar, cb) =>
                @_getCalendarFromCozy calendar.calendar_displayName
                , (err, tag) ->
                    return cb err if err
                    if ACH.color2Android(tag.color) isnt calendar.calendar_color

                        # update calendar !
                        newCalendar = _.extend tag, ACCOUNT
                        newCalendar = ACH.calendar2Android newCalendar
                        newCalendar._id = calendar._id
                        navigator.calendarsync.updateCalendar newCalendar
                        , ACCOUNT, cb

                    else cb()
            , callback


    addCalendar: (name, callback) ->
        log.debug "enter addCalendar"
        # Fetch the calendar object from Cozy.
        @_getCalendarFromCozy name, (err, calendar) =>
            calendar = _.extend calendar, ACCOUNT

            # Add calendar in phone
            navigator.calendarsync.addCalendar ACH.calendar2Android(calendar)
            , (err, calendarId) =>
                return callback err if err

                @calendarIds[name] = calendarId
                @calendarNames[calendarId] = name
                callback null, calendarId


    # Update event in pouchDB with specified event from phone.
    # @param aEvent
    # @param retry retry lighter update after a failed one.
    _updateEventInPouch: (aEvent, callback) ->
        @db.get aEvent._sync_id, (err, cozyEvent) =>
            return callback err if err

            cozyEvent = ACH.event2Cozy aEvent, @calendarNames, cozyEvent

            @db.put cozyEvent, cozyEvent._id, cozyEvent._rev, (err, idNrev) ->
                if err
                    if err.status is 409 # conflict, bad _rev
                        log.error "UpdateInPouch, immediate conflict with \
                            #{cozyEvent._id}.", err
                        # no error, no undirty, will try again next step.
                        return callback null
                    else if err.message is "Some query argument is invalid"
                        log.error "While retrying update event in pouch"
                        , err
                        # Continue with next one.
                        return callback null
                    else
                        return callback err

                aEvent.sync_data2 = idNrev.rev
                aEvent.sync_data5 = cozyEvent.lastModified
                navigator.calendarsync.undirtyEvent aEvent, ACCOUNT, callback


    # Create a new contact in app's pouchDB from newly created phone contact.
    # @param phoneContact cordova contact format.
    # @param retry retry lighter update after a failed one.
    _createEventInPouch: (aEvent, callback) ->
        cozyEvent = ACH.event2Cozy aEvent, @calendarNames

        @db.post cozyEvent, (err, idNrev) ->
            if err
                if err.message is "Some query argument is invalid"
                    log.error "While retrying create event in pouch"
                    , err
                    # Continue with next one.
                    return callback null
                else
                    return callback err

            aEvent._sync_id = idNrev.id
            aEvent.sync_data2 = idNrev.rev

            navigator.calendarsync.undirtyEvent aEvent, ACCOUNT, callback


    # Delete the specified contact in app's pouchdb.
    # @param phoneContact cordova contact format.
    _deleteEventInPouch: (aEvent, callback) ->
        toDelete =
            docType: 'event'
            _id: aEvent._sync_id
            _rev: aEvent.sync_data2
            _deleted: true

        @db.put toDelete, toDelete._id, toDelete._rev, (err, res) ->
            navigator.calendarsync.deleteEvent aEvent, ACCOUNT, callback


    # Sync dirty (modified) phone contact to app's pouchDB.
    syncEventsPhone2Pouch: (callback) ->
        log.info "enter syncPhone2Pouch"
        # Go through modified events (dirtys)
        # delete, update or create....
        navigator.calendarsync.dirtyEvents ACCOUNT, (err, events) =>
            return callback err if err

            processed = 0
            @set 'backup_step', 'calendars_sync_to_pouch'
            @set 'backup_step_total', events.length
            log.info "syncPhone2Pouch #{events.length} events."

            async.eachSeries events, (event, cb) =>
                @set 'backup_step_done', processed++
                setImmediate => # helps refresh UI
                    if event.deleted
                        @_deleteEventInPouch event, cb
                    else
                        event = ACH.filterOrganizerAttendee event, ACCOUNT_NAME
                        if event._sync_id
                            @_updateEventInPouch event, cb
                        else
                            @_createEventInPouch event, cb
            , callback


    # Check for conflicts, resolve them, keeping the given cozy's doc.
    # @param doc the doc to work on
    # @param callback the keeped doc
    handleConflict: (doc, callback) ->
        # Get the doc with conflicts from Pouch
        @db.get doc._id, { conflicts: true, revs: true }, (err, local) =>
            return callback err if err
            return callback null, doc unless local._conflicts?

            log.info "handleConflict fixes for #{doc._id}"
            # Handle conflicts !
            # Remove all conflicts keeping version from cozy
            revsToDelete = local._conflicts.filter (rev) -> rev isnt doc._rev

            # If cozy's rev was in conflict, remove the other one
            if revsToDelete.length isnt local._conflicts.length
                revNum = parseInt doc._rev.split('-')[0]
                idx = local._revisions.start - revNum
                revsToDelete.push "#{revNum}-#{local._revisions.ids[idx]}"

            # Apply clean up.
            async.each revsToDelete, (rev, cb) =>
                @db.remove doc._id, rev, cb
            , (err) ->
                callback err, doc


    # Sync app's pouchDB with cozy's couchDB with a replication.
    syncEventsToCozy: (callback) ->
        log.info "enter sync2Cozy"


        replication = @db.replicate.to @config.remote,
            batch_size: 20
            batches_limit: 5
            filter: (doc) ->
                return doc? and doc.docType?.toLowerCase() is 'event'
            live: false
            since: @config.get 'eventsPushCheckpointed'

        replication.on 'error', callback
        replication.on 'complete', (result) =>
            @config.save eventsPushCheckpointed: result.last_seq, callback


    _checkCalendarInPhone: (cozyEvent, callback) ->
        unless cozyEvent.tags[0] of @calendarIds
            @addCalendar cozyEvent.tags[0], callback
        else callback()


    # Create or update phoneConctact with cozyContact data.
    # @param cozyContact in cozy's format
    # @param phoneContact in cordova contact format.
    _saveEventInPhone: (cozyEvent, androidEvent, callback) ->
        @_checkCalendarInPhone cozyEvent, (err) =>
            return callback err if err
            toSaveInPhone = ACH.event2Android cozyEvent, @calendarIds

            options =
                accountType: ACCOUNT_TYPE
                accountName: ACCOUNT_NAME
            if androidEvent?
                toSaveInPhone._id = androidEvent._id
                navigator.calendarsync.updateEvent toSaveInPhone, options
                , callback

            else
                navigator.calendarsync.addEvent toSaveInPhone, options
                , callback


    cleanCalendars: (calendars, callback) ->
        if calendars.length is 0
            return callback()

        log.info "cleanCalendars"

        async.eachSeries calendars, (calendar, cb) =>
            @db.query 'Calendars'
            ,
                key: calendar.calendar_displayName
                limit: 1
            , (err, res) =>
                return cb err if err
                if res.rows.length > 0
                    return cb()

                log.debug "delete calendar: #{calendar._id}"
                navigator.calendarsync.deleteCalendar calendar, ACCOUNT
                , (err, deletedCount) =>
                    if err or deletedCount isnt 1
                        return cb err

                    delete @calendarIds[calendar.calendar_displayName]
                    delete @calendarNames[calendar._id]
                    cb()
        , callback



    # Update contacts in phone with specified docs.
    # @param docs list of contact in cozy's format.
    _applyEventsChangeToPhone: (docs, callback) ->
        calendarDeletions = {}
        async.eachSeries docs, (doc, cb) =>
            # precondition: backup_step_done initialized to 0.
            @set 'backup_step_done', @get('backup_step_done') + 1
            navigator.calendarsync.eventBySyncId doc._id, (err, aEvents) =>
                aEvent = aEvents[0]
                return cb err if err

                if doc._deleted
                    if aEvent?
                        calendarDeletions[aEvent.calendar_id] = true
                        navigator.calendarsync.deleteEvent aEvent, ACCOUNT, cb
                    else # already done.
                        cb()

                else
                    @_saveEventInPhone doc, aEvent, cb
        , (err) =>
            return callback err if err
            # Remove obsolete calendars.
            calendars = Object.keys(calendarDeletions).map (calendarId) =>
                calendar =
                    _id: calendarId
                    calendar_displayName: @calendarNames[calendarId]
            @cleanCalendars calendars, callback


    # Sync cozy's contact to phone.
    syncEventsFromCozy: (callback) ->
        log.info "enter syncEventFromCozy"

        # Get contacts from the cozy (couch -> pouch replication)
        replication = @db.replicate.from @config.remote,
            batch_size: 20
            batches_limit: 1
            filter: (doc) ->
                return doc? and doc.docType?.toLowerCase() is 'event'
            live: false
            since: @config.get 'eventsPullCheckpointed'

        replication.on 'change', (changes) =>
            @changesFromCozy = @changesFromCozy.concat changes.docs

        replication.on 'error', callback
        replication.on 'complete', (result) =>
            @config.save eventsPullCheckpointed: result.last_seq, callback


    # Initial replication task.
    # @param lastSeq lastseq in remote couchDB.
    initEventsInPhone: (callback) ->
        unless @config.get 'syncCalendars'
            return callback()

        url = '/_changes?descending=true&limit=1'
        request.get @config.makeReplicationUrl(url), (err, res, body) =>
            return cb err if err
            # we store last_seq before copying files & folder
            # to avoid losing changes occuring during replication
            lastSeq = body.last_seq

            @createAccount (err) =>
                @updateCalendars (err) =>
                    return callback err if err
                    options = @config.makeDSUrl "/request/event/all/"
                    options.body =
                        include_docs: true
                        show_revs: true
                    request.post options, (err, res, rows) =>
                        return callback err if err
                        return callback null unless rows?.length

                        async.mapSeries rows, (row, cb) =>
                            doc = row.doc
                            @db.put doc, new_edits: false, (err, res) ->
                                                                cb err, doc
                        , (err, docs) =>
                            return callback err if err
                            @set 'backup_step', null # hide header: first-sync view
                            @_applyEventsChangeToPhone docs, (err) =>
                                # clean backup_step_done after applyChanges
                                @set 'backup_step_done', null
                                @config.save eventsPullCheckpointed: lastSeq
                                , (err) =>
                                    @deleteObsoletePhoneEvents callback


    # Synchronise delete state between pouch and the phone.
    deleteObsoletePhoneEvents: (callback) ->
        log.info "enter deleteObsoletePhoneEvents"
        async.parallel
            phone: (cb) ->
                navigator.calendarsync.allEvents ACCOUNT, cb

            pouch: (cb) =>
                @db.query DesignDocuments.CALENDARS, {}, cb

            calendar: (cb) ->
                navigator.calendarsync.allCalendars ACCOUNT, cb


        , (err, events) =>
            return callback err if err
            idsInPouch = {}
            for row in events.pouch.rows
                idsInPouch[row.id] = true

            async.eachSeries events.phone, (aEvent, cb) ->
                if aEvent._sync_id of idsInPouch
                    cb()
                else
                    log.info "Delete event: #{aEvent._sync_id}"
                    navigator.calendarsync.deleteEvent aEvent, ACCOUNT, cb
            , (err) =>
                return callback err if err
                @cleanCalendars events.calendar, callback
