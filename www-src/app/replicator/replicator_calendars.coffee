request = require '../lib/request'
ACH = require 'lib/android_calendar_helper'


# Account type and name of the created android contact account.
ACCOUNT_TYPE = 'io.cozy'
ACCOUNT_NAME = 'myCozy'

ACCOUNT =
    accountType: ACCOUNT_TYPE
    accountName: ACCOUNT_NAME

log = require('/lib/persistent_log')
    prefix: "calendars replicator"
    date: true


module.exports =
    # TODO !

    # 'main' function for contact synchronisation.
    syncCalendars: (callback) ->
        return callback null unless @config.get 'syncCalendars'

        # Feedback to the user.
        @set 'backup_step', 'calendar_sync'
        @set 'backup_step_done', null

        # Phone is right on conflict.
        # Contact sync has 4 phases
        # 1 - contacts initialisation (if necessary)
        # 2 - sync Phone --> in app PouchDB
        # 3 - sync in app PouchDB --> Cozy couchDB
        # 4 - sync Cozy couchDB to phone (and app PouchDB)
        async.series [
            (cb) =>
                if @config.has('eventsPullCheckpointed')
                    cb()
                else
                    request.get @config.makeUrl('/_changes?descending=true&limit=1')
                    , (err, res, body) =>
                        return cb err if err
                        # we store last_seq before copying files & folder
                        # to avoid losing changes occuring during replication
                        @initEventsInPhone body.last_seq, cb
            (cb) => @fetchCalendarsFromPhone cb
            (cb) => @syncPhone2Pouch cb
            (cb) => @syncToCozy cb
            (cb) => @syncFromCozy cb
        ], (err) ->
            log.info "Sync calendars done"
            callback err


    # Create the myCozyCloud account in android.
    # TODO : in navigator.contacts ? navigator.calendars ?
    createAccount: (callback) =>
        navigator.calendarsync.createAccount ACCOUNT_TYPE, ACCOUNT_NAME
        , ->
            callback null
        , callback


    fetchCalendarsFromPhone: (callback) ->
        options =
            accountType: ACCOUNT_TYPE
            accountName: ACCOUNT_NAME

        navigator.calendarsync.allCalendars options, (err, calendars) =>
            return callback err if err

            @calendarIds = {}
            for calendar in calendars
                log.debug calendar
                @calendarIds[calendar.calendar_displayName] = calendar._id

            @calendarNames = _.invert @calendarIds
            callback null, calendars


    addCalendar: (name, callback) ->
        log.debug "enter addCalendar"
        # Fecth the calendar object from Cozy.
        request.get @config.makeUrl("/_design/tag/_view/byname?key=\"#{name}\"")
        , (err, res, body) =>
            return callback err if err # TODO : pass on 404
            # No tag found, put a default color.
            calendar = body.rows?[0].value or { name: name , color: '#2979FF' }

            options =
                accountName: ACCOUNT_NAME
                accountType: ACCOUNT_TYPE

            calendar = _.extend calendar, options

            # Add calendar in phone
            navigator.calendarsync.addCalendar ACH.calendar2Android(calendar)
            , (err, calendarId) =>
                return callback err if err

                @calendarIds[name] = calendarId
                console.log @calendarIds
                callback null, calendarId


    # Update event in pouchDB with specified event from phone.
    # @param aEvent
    # @param retry retry lighter update after a failed one.
    _updateInPouch: (aEvent, callback) ->
        @db.get aEvent._sync_id, (err, cozyEvent) =>
            return callback err if err

            cozyEvent = ACH.event2Cozy aEvent, @calendarNames, cozyEvent

            @db.put cozyEvent, cozyEvent._id, cozyEvent._rev, (err, idNrev) =>
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
    _createInPouch: (aEvent, callback) ->
        cozyEvent = ACH.event2Cozy aEvent, @calendarNames

        @db.post cozyEvent, (err, idNrev) =>
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
    _deleteInPouch: (aEvent, callback) ->
        toDelete =
            docType: 'event'
            _id: aEvent._sync_id
            _rev: aEvent.sync_data2
            _deleted: true

        @db.put toDelete, toDelete._id, toDelete._rev, (err, res) ->
            navigator.calendarsync.deleteEvent aEvent, ACCOUNT, callback


    # Sync dirty (modified) phone contact to app's pouchDB.
    syncPhone2Pouch: (callback) ->
        log.info "enter syncPhone2Pouch"
        # Go through modified events (dirtys)
        # delete, update or create....
        navigator.calendarsync.dirtyEvents ACCOUNT, (err, events) =>
            return callback err if err

            processed = 0
            @set 'backup_step', 'calendars_sync_to_pouch'
            @set 'backup_step_total', events.length
            log.info "syncPhone2Pouch #{events.length} contacts."

            async.eachSeries events, (event, cb) =>
                @set 'backup_step_done', processed++
                setImmediate => # helps refresh UI
                    if event.deleted
                        @_deleteInPouch event, cb
                    else if event._sync_id
                        @_updateInPouch event, cb
                    else
                        @_createInPouch event, cb
            , callback



    # Sync app's pouchDB with cozy's couchDB with a replication.
    syncToCozy: (callback) ->
        log.info "enter sync2Cozy"
        @set 'backup_step_done', null
        @set 'backup_step', 'events_sync_to_cozy'

        replication = @db.replicate.to @config.remote,
            batch_size: 20
            batches_limit: 5
            filter: (doc) ->
                return doc? and doc.docType?.toLowerCase() is 'event'
            live: false
            since: @config.get 'eventsPushCheckpointed'

        #TODO : replication.on 'change', (e) => return
        replication.on 'error', callback
        replication.on 'complete', (result) =>
            @config.save eventsPushCheckpointed: result.last_seq, callback

    # TODO : on delete from phone.
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
                console.log "after qeury"
                console.log err
                console.log res
                return cb err if err
                if res.rows.length > 0
                    return cb()

                navigator.calendarsync.deleteCalendar calendar, ACCOUNT
                , (err, deletedCount) =>
                    console.log "after delete"
                    if err or deletedCount isnt 1
                        return cb err

                    delete @calendarIds[calendar.calendar_displayName]
                    cb()
        , callback


    # TODO !

    # Update contacts in phone with specified docs.
    # @param docs list of contact in cozy's format.
    _applyChangeToPhone: (docs, callback) ->
        calendarDeletions = {}
        async.eachSeries docs, (doc, cb) =>
            console.log doc
            # precondition: backup_step_done initialized to 0.
            @set 'backup_step_done', @get('backup_step_done') + 1
            navigator.calendarsync.eventBySyncId doc._id, (err, aEvents) =>
                console.log aEvents
                aEvent = aEvents[0]
                return cb err if err
                # TODO.
                options =
                    accountType: ACCOUNT_TYPE
                    accountName: ACCOUNT_NAME
                if doc._deleted
                    if aEvent?
                        calendarDeletions[aEvent.calendar_id] = true
                        navigator.calendarsync.deleteEvent aEvent, options, cb
                    # else already done.

                else
                    @_saveEventInPhone doc, aEvent, cb
        , (err) =>
            return callback err if err
            # Remove obsolete calendars.
            calendars = Object.keys(calendarDeletions).map (calendarId) =>
                calendar =
                    _id: calendarId
                    calendar_displayName: _.invert(@calendarIds)[calendarId]
            @cleanCalendars calendars, callback


    # TODO !
    # Sync cozy's contact to phone.
    syncFromCozy: (callback) ->
        log.info "enter syncCozy2Phone"
        replicationDone = false

        total = 0
        @set 'backup_step', 'events_sync_to_phone'
        @set 'backup_step_done', 0

        # Use a queue because contact save to phone doesn't support well
        # concurrency.
        applyToPhoneQueue = async.queue @_applyChangeToPhone.bind @

        applyToPhoneQueue.drain = -> callback() if replicationDone

        # Get contacts from the cozy (couch -> pouch replication)
        replication = @db.replicate.from @config.remote,
            batch_size: 20
            batches_limit: 1
            filter: (doc) ->
                return doc? and doc.docType?.toLowerCase() is 'event'
            live: false
            since: @config.get 'eventsPullCheckpointed'

        replication.on 'change', (changes) =>
            # hack: whitout it, doc becomes _id value !
            applyToPhoneQueue.push $.extend true, {}, changes.docs
            total += changes.docs?.length
            @set 'backup_step_total', total
            log.info "sync2Phone #{total} events."

        replication.on 'error', callback
        replication.on 'complete', (result) =>
            @config.save eventsPullCheckpointed: result.last_seq, ->
                replicationDone = true
                if applyToPhoneQueue.idle()
                    applyToPhoneQueue.drain = null
                    callback()


    # Initial replication task.
    # @param lastSeq lastseq in remote couchDB.
    initEventsInPhone: (lastSeq, callback) ->
        unless @config.get 'syncCalendars'
            return callback()

        @createAccount (err) =>
          @fetchCalendarsFromPhone (err) =>
            return callback err if err
            console.log @calendarIds

            # Fetch events from view all of contact app.
            # TODO : if view doesn't exist ?
            request.get @config.makeUrl("/_design/event/_view/all/")
            , (err, res, body) =>
                return callback err if err
                return callback null unless body.rows?.length

                async.mapSeries body.rows, (row, cb) =>
                    doc = row.value
                    @db.put doc, 'new_edits':false, (err, res) -> cb err, doc
                , (err, docs) =>
                    console.log docs
                    return callback err if err
                    @set 'backup_step', null # hide header: first-sync view
                    @_applyChangeToPhone docs, (err) =>
                        # clean backup_step_done after applyChanges
                        @set 'backup_step_done', null
                        @config.save eventsPullCheckpointed: lastSeq
                        , callback
                        # , (err) =>
                            # @deleteObsoletePhoneContacts callback


    # TODO !
    # Synchronise delete state between pouch and the phone.
    deleteObsoletePhoneContacts: (callback) ->
        log.info "enter deleteObsoletePhoneContacts"
        async.parallel
            phone: (cb) ->
                navigator.contacts.find [navigator.contacts.fieldType.id]
                , (contacts) ->
                    cb null, contacts
                , cb
                , new ContactFindOptions "", true, [], ACCOUNT_TYPE, ACCOUNT_NAME
            pouch: (cb) =>
                @db.query "Contacts", {}, cb

        , (err, contacts) =>
            return callback err if err
            idsInPouch = {}
            for row in contacts.pouch.rows
                idsInPouch[row.id] = true

            async.eachSeries contacts.phone, (contact, cb) =>
                unless contact.sourceId of idsInPouch
                    log.info "Delete contact: #{contact.sourceId}"
                    return contact.remove (-> cb()), cb, \
                        callerIsSyncAdapter: true
                return cb()
            , callback
