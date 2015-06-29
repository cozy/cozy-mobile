request = require '../lib/request'
Contact = require '../models/contact'

# Account type and name of the created android contact account.
ACCOUNT_TYPE = 'io.cozy'
ACCOUNT_NAME = 'myCozy'


module.exports =

    syncContacts: (callback) ->
        return callback null unless @config.get 'syncContacts'

        @set 'backup_step', 'contacts_sync'
        @set 'backup_step_done', null
        # Phone is right on conflict.
        # Contact sync has 3 phases
        # 1 - Phone2Pouch
        # 2 - Pouch <-> Couch (cozy)
        # 3 - Pouch2Phone.

        async.series [
            (cb) => @syncPhone2Pouch cb
            (cb) => @_syncToCozy cb
            (cb) => @syncFromCozyToPouchToPhone cb
        ], (err) ->
            console.log "Sync contacts done"
            callback err

    createAccount: (callback) =>
        navigator.contacts.createAccount ACCOUNT_TYPE, ACCOUNT_NAME
        , ->
            callback null
        , callback

    # Sync phone to pouch components
    _updateInPouch: (phoneContact, callback) ->
        async.parallel
            fromPouch: (cb) =>
                @db.get phoneContact.sourceId,  attachments: true, cb

            fromPhone: (cb) ->
                Contact.cordova2Cozy phoneContact, cb
        , (err, res) =>
            return callback err if err

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
                        console.log "UpdateInPouch, immediate conflict with #{contact._id}."
                        console.log err
                        # no error, no undirty, will try again next step.
                        return callback null
                    else
                        return callback err

                @_undirty phoneContact, idNrev, callback


    _createInPouch: (phoneContact, callback) ->
        Contact.cordova2Cozy phoneContact, (err, fromPhone) =>
            contact = _.extend
                docType: 'contact'
                tags: []
            , fromPhone

            if contact._attachments?.picture?
                contact._attachments.picture.revpos = 1

            @db.post contact, (err, idNrev) =>
                return callback err if err
                @_undirty phoneContact, idNrev, callback


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


    _deleteInPouch: (phoneContact, callback) ->
        toDelete =
            docType: 'contact'
            _id: phoneContact.sourceId
            _rev: phoneContact.sync2
            _deleted: true

        @db.put toDelete, toDelete._id, toDelete._rev, (err, res) =>
            phoneContact.remove (-> callback()), callback, callerIsSyncAdapter: true


    syncPhone2Pouch: (callback) ->
        # Go through modified contacts (dirtys)
        # delete, update or create....
        navigator.contacts.find [navigator.contacts.fieldType.dirty]
        , (contacts) =>
            async.eachSeries contacts, (contact, cb) =>
                if contact.deleted
                    @_deleteInPouch contact, cb
                else if contact.sourceId
                    @_updateInPouch contact, cb
                else
                    @_createInPouch contact, cb
            , callback

        , callback
        , new ContactFindOptions "1", true, [], ACCOUNT_TYPE, ACCOUNT_NAME


    _syncToCozy: (callback) ->
        # Get contacts from the cozy (couch -> pouch replication)
        replication = app.replicator.db.replicate.to app.replicator.config.remote,
            batch_size: 20
            batches_limit: 5
            filter: (doc) ->
                return doc? and doc.docType?.toLowerCase() is 'contact'
            live: false
            since: app.replicator.config.get 'contactsPushCheckpointed'

        replication.on 'change', (e) => return
        replication.on 'error', callback
        replication.on 'complete', (result) =>
            app.replicator.config.save contactsPushCheckpointed: result.last_seq,  callback

    _saveContactInPhone: (cozyContact, phoneContact, callback) ->
        toSave = Contact.cozy2Cordova cozyContact

        if phoneContact
            toSave.id = phoneContact.id
            toSave.rawId = phoneContact.rawId

        options =
            accountType: ACCOUNT_TYPE
            accountName: ACCOUNT_NAME
            callerIsSyncAdapter: true
            resetFields: true

        toSave.save (contact)->
            callback null, contact
        , callback, options


    _applyChangeToPhone: (docs, callback) ->
        getBySourceId = (sourceId, cb) ->
            navigator.contacts.find [navigator.contacts.fieldType.sourceId]
                , (contacts) ->
                    cb null, contacts[0]
                , cb
                , new ContactFindOptions sourceId, false, [], ACCOUNT_TYPE, ACCOUNT_NAME

        async.eachSeries docs, (doc, cb) =>
            getBySourceId doc._id, (err, contact) =>
                return cb err if err
                if doc._deleted
                    contact.remove (-> cb()), cb, callerIsSyncAdapter: true

                else
                    @_saveContactInPhone doc, contact, cb
        , (err) ->
            callback err


    syncFromCozyToPouchToPhone: (callback) ->
        replicationDone = false

        q = async.queue @_applyChangeToPhone.bind @

        q.drain = -> callback() if replicationDone

        # Get contacts from the cozy (couch -> pouch replication)
        replication = @db.replicate.from @config.remote,
            batch_size: 20
            batches_limit: 1
            filter: (doc) ->
                return doc? and doc.docType?.toLowerCase() is 'contact'
            live: false
            since: @config.get 'contactsPullCheckpointed'

        replication.on 'change', (e) =>
            q.push $.extend(true, {}, e.docs) # whitout doc become _id value !

        replication.on 'error', callback
        replication.on 'complete', (result) =>
            @config.save contactsPullCheckpointed: result.last_seq, ->
                replicationDone = true
                if q.idle()
                    q.drain = null
                    callback()


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
