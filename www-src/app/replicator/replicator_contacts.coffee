request = require '../lib/request'
Contact = require '../models/contact'

# Account type and name of the created android contact account.
ACCOUNT_TYPE = 'io.cozy'
ACCOUNT_NAME = 'myCozy'

log = require('/lib/persistent_log')
    prefix: "contacts replicator"
    date: true


module.exports =

    # 'main' function for contact synchronisation.
    syncContacts: (callback) ->
        return callback null unless @config.get 'syncContacts'

        # Feedback to the user.
        @set 'backup_step', 'contacts_sync'
        @set 'backup_step_done', null

        # Phone is right on conflict.
        # Contact sync has 4 phases
        # 1 - contacts initialisation (if necessary)
        # 2 - sync Phone --> in app PouchDB
        # 3 - sync in app PouchDB --> Cozy couchDB
        # 4 - sync Cozy couchDB to phone (and app PouchDB)
        async.series [
            (cb) =>
                if @config.has('contactsPullCheckpointed')
                    cb()
                else
                    request.get @config.makeReplicationUrl('/_changes?descending=true&limit=1')
                    , (err, res, body) =>
                        return cb err if err
                        # we store last_seq before copying files & folder
                        # to avoid losing changes occuring during replication
                        @initContactsInPhone body.last_seq, cb

            (cb) => @syncPhone2Pouch cb
            (cb) => @syncToCozy cb
            (cb) => @syncFromCozyToPouchToPhone cb
        ], (err) ->
            log.info "Sync contacts done"
            callback err


    # Create the myCozyCloud account in android.
    createAccount: (callback) =>
        navigator.contacts.createAccount ACCOUNT_TYPE, ACCOUNT_NAME
        , ->
            callback null
        , callback


    # Update contact in pouchDB with specified contact from phone.
    # @param phoneContact cordova contact format.
    # @param retry retry lighter update after a failed one.
    _updateInPouch: (phoneContact, callback) ->
        async.parallel
            fromPouch: (cb) =>
                @db.get phoneContact.sourceId,  attachments: true, cb

            fromPhone: (cb) ->
                Contact.cordova2Cozy phoneContact, cb
        , (err, res) =>
            return callback err if err

            # _.extend : Keeps not android compliant data of the 'cozy'-contact
            contact = _.extend res.fromPouch, res.fromPhone

            if contact._attachments?.picture?
                picture = contact._attachments.picture

                if res.fromPouch._attachments?.picture?
                    oldPicture = res.fromPouch._attachments?.picture?
                    if oldPicture.data is picture.data
                        picture.revpos = oldPicture.revpos
                    else
                        picture.revpos = 1 + parseInt contact._rev.split('-')[0]
            @db.put contact, contact._id, contact._rev, (err, idNrev) =>
                if err
                    if err.status is 409 # conflict, bad _rev
                        log.error "UpdateInPouch, immediate conflict with \
                            #{contact._id}.", err
                        # no error, no undirty, will try again next step.
                        return callback null
                    else if err.message is "Some query argument is invalid"
                        log.error "While retrying update contact in pouch"
                        , err
                        # Continue with next one.
                        return callback null
                    else
                        return callback err

                @_undirty phoneContact, idNrev, callback


    # Create a new contact in app's pouchDB from newly created phone contact.
    # @param phoneContact cordova contact format.
    # @param retry retry lighter update after a failed one.
    _createInPouch: (phoneContact, callback) ->
        Contact.cordova2Cozy phoneContact, (err, fromPhone) =>
            contact = _.extend
                docType: 'contact'
                tags: []
            , fromPhone

            if contact._attachments?.picture?
                contact._attachments.picture.revpos = 1

            @db.post contact, (err, idNrev) =>
                if err
                    if err.message is "Some query argument is invalid"
                        log.error "While retrying create contact in pouch"
                        , err
                        # Continue with next one.
                        return callback null
                    else
                        return callback err

                @_undirty phoneContact, idNrev, callback


    # Notify to Android that the contact have been synchronized with the server.
    # @param dirtyContact cordova contact format.
    # @param idNrew object with id and rev of pouchDB contact.
    _undirty: (dirtyContact, idNrev, callback) ->
        # undirty and set id and rev on phone contact.
        dirtyContact.dirty = false
        dirtyContact.sourceId = idNrev.id
        dirtyContact.sync2 = idNrev.rev

        dirtyContact.save () ->
            callback null
        , callback
        ,
            accountType: ACCOUNT_TYPE
            accountName: ACCOUNT_NAME
            callerIsSyncAdapter: true


    # Delete the specified contact in app's pouchdb.
    # @param phoneContact cordova contact format.
    _deleteInPouch: (phoneContact, callback) ->
        toDelete =
            docType: 'contact'
            _id: phoneContact.sourceId
            _rev: phoneContact.sync2
            _deleted: true

        @db.put toDelete, toDelete._id, toDelete._rev, (err, res) =>
            phoneContact.remove (-> callback()), callback, callerIsSyncAdapter: true


    # Sync dirty (modified) phone contact to app's pouchDB.
    syncPhone2Pouch: (callback) ->
        log.info "enter syncPhone2Pouch"
        # Go through modified contacts (dirtys)
        # delete, update or create....
        navigator.contacts.find [navigator.contacts.fieldType.dirty]
        , (contacts) =>
            processed = 0
            @set 'backup_step', 'contacts_sync_to_pouch'
            @set 'backup_step_total', contacts.length
            log.info "syncPhone2Pouch #{contacts.length} contacts."
            # contact to update number. contacts.length
            async.eachSeries contacts, (contact, cb) =>
                @set 'backup_step_done', processed++
                setImmediate => # helps refresh UI
                    if contact.deleted
                        @_deleteInPouch contact, cb
                    else if contact.sourceId
                        @_updateInPouch contact, cb
                    else
                        @_createInPouch contact, cb
            , callback

        , callback
        , new ContactFindOptions "1", true, [], ACCOUNT_TYPE, ACCOUNT_NAME


    # Sync app's pouchDB with cozy's couchDB with a replication.
    syncToCozy: (callback) ->
        log.info "enter sync2Cozy"
        @set 'backup_step_done', null
        @set 'backup_step', 'contacts_sync_to_cozy'

        replication = @db.replicate.to @config.remote,
            batch_size: 20
            batches_limit: 5
            filter: (doc) ->
                return doc? and doc.docType?.toLowerCase() is 'contact'
            live: false
            since: @config.get 'contactsPushCheckpointed'

        #TODO : replication.on 'change', (e) => return
        replication.on 'error', callback
        replication.on 'complete', (result) =>
            @config.save contactsPushCheckpointed: result.last_seq, callback


    # Create or update phoneConctact with cozyContact data.
    # @param cozyContact in cozy's format
    # @param phoneContact in cordova contact format.
    _saveContactInPhone: (cozyContact, phoneContact, callback) ->
        toSaveInPhone = Contact.cozy2Cordova cozyContact

        if phoneContact
            toSaveInPhone.id = phoneContact.id
            toSaveInPhone.rawId = phoneContact.rawId

        options =
            accountType: ACCOUNT_TYPE
            accountName: ACCOUNT_NAME
            callerIsSyncAdapter: true # apply immediately
            resetFields: true # remove all fields before update

        toSaveInPhone.save (contact)->
            callback null, contact
        , callback, options


    # Update contacts in phone with specified docs.
    # @param docs list of contact in cozy's format.
    _applyChangeToPhone: (docs, callback) ->
        getFromPhoneBySourceId = (sourceId, cb) ->
            navigator.contacts.find [navigator.contacts.fieldType.sourceId]
                , (contacts) ->
                    cb null, contacts[0]
                , cb
                , new ContactFindOptions sourceId, false, [], ACCOUNT_TYPE, ACCOUNT_NAME

        async.eachSeries docs, (doc, cb) =>
            # precondition: backup_step_done initialized to 0.
            @set 'backup_step_done', @get('backup_step_done') + 1
            getFromPhoneBySourceId doc._id, (err, contact) =>
                return cb err if err
                if doc._deleted
                    if contact?
                        # Use callerIsSyncAdapter flag to apply immediately in
                        # android(no dirty flag cycle)
                        contact.remove (-> cb()), cb, callerIsSyncAdapter: true
                    # else already done.

                else
                    @_saveContactInPhone doc, contact, cb
        , (err) ->
            callback err


    # Sync cozy's contact to phone.
    syncFromCozyToPouchToPhone: (callback) ->
        log.info "enter syncCozy2Phone"
        replicationDone = false

        total = 0
        @set 'backup_step', 'contacts_sync_to_phone'
        @set 'backup_step_done', 0

        # Ues a queue because contact save to phone doesn't support well
        # concurrency.
        applyToPhoneQueue = async.queue @_applyChangeToPhone.bind @

        applyToPhoneQueue.drain = -> callback() if replicationDone

        # Get contacts from the cozy (couch -> pouch replication)
        replication = @db.replicate.from @config.remote,
            batch_size: 20
            batches_limit: 1
            filter: (doc) ->
                return doc? and doc.docType?.toLowerCase() is 'contact'
            live: false
            since: @config.get 'contactsPullCheckpointed'

        replication.on 'change', (changes) =>
            # hack: whitout it, doc becomes _id value !
            applyToPhoneQueue.push $.extend true, {}, changes.docs
            total += changes.docs?.length
            @set 'backup_step_total', total
            log.info "sync2Phone #{total} contacts."



        replication.on 'error', callback
        replication.on 'complete', (result) =>
            @config.save contactsPullCheckpointed: result.last_seq, ->
                replicationDone = true
                if applyToPhoneQueue.idle()
                    applyToPhoneQueue.drain = null
                    callback()


    # Initial replication task.
    # @param lastSeq lastseq in remote couchDB.
    initContactsInPhone: (lastSeq, callback) ->
        unless @config.get 'syncContacts'
            return callback()

        @createAccount (err) =>
            # Fetch contacs from view all of contact app.
            options = @config.makeDSUrl("/request/contact/all/")
            options.body = {}
            request.post options, (err, res, rows) =>
                return callback err if err
                return callback null unless rows?.length

                async.mapSeries rows, (row, cb) =>
                    doc = row.value
                    # fetch attachments if exists.
                    if doc._attachments?.picture?
                        request.get @config.makeReplicationUrl(
                            "/#{doc._id}?attachments=true")
                        , (err, res, body) ->
                            return cb err if err
                            cb null, body
                    else
                        cb null, doc
                , (err, docs) =>
                    return callback err if err
                    async.mapSeries docs, (doc, cb) =>
                        @db.put doc, 'new_edits':false, cb
                    , (err, contacts) =>
                        return callback err if err
                        @set 'backup_step', null # hide header: first-sync view
                        @_applyChangeToPhone docs, (err) =>
                            # clean backup_step_done after applyChanges
                            @set 'backup_step_done', null
                            @config.save contactsPullCheckpointed: lastSeq
                            , (err) =>
                                @deleteObsoletePhoneContacts callback


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
