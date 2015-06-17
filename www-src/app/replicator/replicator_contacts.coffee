request = require '../lib/request'
Contact = require '../models/contact'
Utils = require './utils'

# Account type and name of the created android contact account.
ACCOUNT_TYPE = 'io.cozy'
ACCOUNT_NAME = 'myCozy'


module.exports =

    testSyncContacts: (callback) ->
        # @initContactsInPhone (err) ->
                # cozyContacts = []
        @syncContacts (err, cozyContacts) ->
            if err
                console.log 'err'
                console.log err
                return callback err

            console.log cozyContacts
            return callback cozyContacts


    syncContacts: (callback) ->
        return callback null unless @config.get 'syncContacts'

        # Phone is right on conflict.
        # Contact sync has 3 phases
        # 1 - Phone2Pouch
        # 2 - Pouch <-> Couch (cozy)
        # 3 - Pouch2Phone.

        async.series [
            # @createAccount
            @syncPhone2Pouch
            @_syncToCozy
            @syncFromCozyToPouchToPhone
            ], callback

    createAccount: (callback) =>
        navigator.contacts.createAccount ACCOUNT_TYPE, ACCOUNT_NAME
        , ->
            callback null
        , (err) ->
            callback err

    # Sync phone to pouch components


    _saveContactInPouch: (cozyContact, callback) ->
        if cozyContact._id # update
            if cozyContact?._attachments?.picture?
                # TODO : clean up ! / avoid update pict on each update.
                cozyContact._attachments.picture.revpos = cozyContact._rev.split('-')[0] + 1

            app.replicator.db.put cozyContact, cozyContact._id, \
            cozyContact._rev, callback

        else # create
            # TODO : clean up !
            if cozyContact?._attachments?.picture?
                cozyContact._attachments.picture.revpos = 1
            app.replicator.db.post cozyContact, callback

    _updateInPouch: (dirtyContact, cb) ->
        # Convert to pouch
        Contact.cordova2Cozy dirtyContact, (err, cozyContact) ->
            return cb err if err

            # Add in pouch
            app.replicator._saveContactInPouch cozyContact, (err, res) ->
                return cb err if err

                # undirty and set id and rev on phone contact.
                dirtyContact.dirty = false
                dirtyContact.sourceId = res.id
                dirtyContact.sync2 = res.rev

                dirtyContact.save () ->
                    cb null, cozyContact
                , cb
                ,
                    accountType: ACCOUNT_TYPE
                    accountName: ACCOUNT_NAME
                    callerIsSyncAdapter: true

    # Delete remaining contacts in pouch.
    _deleteInPouch: (err, contactIds, callback) =>
        return callback err if err

        options =
            include_docs: true
            attachments: false
            keys: Object.keys contactIds

        app.replicator.db.query 'Contacts', options, (err, res) ->
            return callback err if err

            async.each res.rows, (row, cb) ->
                toDelete =
                    docType: 'contact'
                    _id: row.doc._id
                    _rev: row.doc._rev
                    _deleted: true

                app.replicator.db.put toDelete, toDelete._id, toDelete._rev
                , cb
            , callback


    # TODO : clean.
    syncPhone2Pouch: (callback) =>
        # No deleted flags... identify delete by list comparison
        # Go through each phoneContact,
        # mark pouchContacts
        # if dirty, updateorCreate pouchContact
        #
        # delete un-marked pouchContact

        # Get contacts list
        async.parallel
            pouchContacts: (cb) ->
                app.replicator.db.query 'Contacts', { include_docs: false, attachments: false }, cb

            # Get all contacts
            phoneContacts: (cb) ->
                navigator.contacts.find [navigator.contacts.fieldType.id]
                , (contacts) ->
                    console.log "CONTACTS FROM PHONE : #{contacts.length}"
                    console.log contacts

                    cb null, contacts

                , cb
                , new ContactFindOptions "", true, [], ACCOUNT_TYPE, ACCOUNT_NAME
        , (err, res) ->
            return callback err if err

            pouchContactIds = Utils.array2Hash res.pouchContacts.rows, 'id'

            async.each res.phoneContacts, (phoneContact, cb) ->

                delete pouchContactIds[phoneContact.sourceId]
                if phoneContact.dirty
                    app.replicator._updateInPouch phoneContact, cb
                else
                    cb()


            , (err) ->
                app.replicator._deleteInPouch err, pouchContactIds, callback


    _syncToCozy: (callback) =>
        # Get contacts from the cozy (couch -> pouch replication)
        console.log "checkpointedPush: #{app.replicator.config.get 'contactsPushCheckpointed'}"
        replication = app.replicator.db.replicate.to app.replicator.config.remote,
            batch_size: 20
            batches_limit: 5
            filter: (doc) ->
                return doc? and doc.docType?.toLowerCase() is 'contact' # and
                    #not doc._deleted # TODO ! should not need this ! # Pb with attachments ?
            live: false
            #since: app.replicator.config.get 'contactsPushCheckpointed'

        replication.on 'change', (e) =>
            console.log "Replication Change"
            console.log e
        replication.on 'error', callback
        replication.on 'complete', (result) =>
            console.log "REPLICATION COMPLETED contacts"
            console.log result
            app.replicator.config.save contactsPushCheckpointed: result.last_seq,  callback

    _saveContactInPhone: (cozyContact, phoneContact, callback) =>
        toSave = Contact.cozy2Cordova cozyContact

        if phoneContact
            toSave.id = phoneContact.id
            toSave.rawId = phoneContact.rawId

        options =
            accountType: ACCOUNT_TYPE
            accountName: ACCOUNT_NAME
            callerIsSyncAdapter: true

        toSave.save (contact)->
            callback null, contact
        , callback, options


    _applyChangeToPhone: (docs, callback) ->
        getBySourceId = (sourceId, cb) ->
            console.log "get contact: #{sourceId}"
            navigator.contacts.find [navigator.contacts.fieldType.sourceId]
                , (contacts) ->
                    console.log "CONTACTS FROM PHONE : #{contacts.length}"
                    console.log contacts
                    cb null, contacts[0]
                , cb
                , new ContactFindOptions sourceId, false, [], 'io.cozy', 'myCozy'

        async.each docs, (doc, cb) =>
            getBySourceId doc._id, (err, contact) =>
                return cb err if err

                if doc._deleted
                    contact.remove (-> cb()), cb, callerIsSyncAdapter: true

                else
                    @_saveContactInPhone doc, contact, cb
        , (err) ->
            console.log "done changes"
            callback err


    syncFromCozyToPouchToPhone: (callback) ->
        # Get contacts from the cozy (couch -> pouch replication)
        console.log "checkpointedPull: #{app.replicator.config.get 'contactsPullCheckpointed'}"
        replication = app.replicator.db.replicate.from app.replicator.config.remote,
            batch_size: 20
            batches_limit: 5
            filter: (doc) ->
                return doc? and doc.docType?.toLowerCase() is 'contact' # and
                    #not doc._deleted # TODO ! should not need this ! # Pb with attachments ?
            live: false
            since: app.replicator.config.get 'contactsPullCheckpointed'

        replication.on 'change', (e) =>
            console.log "Replication Change"
            console.log e
            app.replicator._applyChangeToPhone e.docs, ->

        replication.on 'error', callback
        replication.on 'complete', (result) =>
            console.log "REPLICATION COMPLETED contacts"
            console.log result
            app.replicator.config.save contactsPullCheckpointed: result.last_seq, callback

    # Initial replication task.
    initContactsInPhone: (callback) ->
        @createAccount (err) =>
            # Fetch contacs from view all of contact app.
            request.get @config.makeUrl("/_design/contact/_view/all/")
            , (err, res, body) =>
                return callback err if err
                return callback null unless body.rows?.length

                async.mapSeries body.rows, (row, cb) =>
                    doc = row.value
                    # fetch attachments if exists.
                    if doc._attachments?.picture?
                        request.get @config.makeUrl("/#{doc._id}?attachments=true")
                        # request.get @config.makeUrl("/#{doc._id}/picture")
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
                        @_applyChangeToPhone docs, callback
