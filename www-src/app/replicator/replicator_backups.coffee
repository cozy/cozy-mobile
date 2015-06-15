DeviceStatus = require '../lib/device_status'
Utils = require './utils'
fs = require './filesystem'
request = require '../lib/request'
Contact = require '../models/contact'

# Account type and name of the created android contact account.
CONTACT_PHONE_ACCOUNT_TYPE = 'io.cozy'
CONTACT_PHONE_ACCOUNT_NAME = 'myCozy'

# This files contains all replicator functions liked to backup
# use the ImagesBrowser cordova plugin to fetch images & contacts
# from phone.
# Set the inBackup attribute to true while a backup is in progress
# Set the backup_step attribute with value in
# [contacts_scan, pictures_sync, contacts_sync]
# For each step, hint of progress are in backup_step_done and backup_step_total

module.exports =

    # wrapper around _backup to maintain the state of inBackup
    backup: (options, callback = ->) ->
        return callback null if @get 'inBackup'

        options = options or { force: false }

        @set 'inBackup', true
        @set 'backup_step', null
        @stopRealtime()
        @_backup options.force, (err) =>
            @set 'backup_step', null
            @set 'inBackup', false
            @startRealtime() unless options.background
            return callback err if err
            @config.save lastBackup: new Date().toString(), (err) =>
                callback null


    _backup: (force, callback) ->
        DeviceStatus.checkReadyForSync true, (err, ready, msg) =>
            console.log "SYNC STATUS", err, ready, msg
            return callback err if err
            return callback new Error(msg) unless ready
            console.log "WE ARE READY FOR SYNC"

            # @syncPictures force, (err) =>
            #     console.log "done syncPict"
            #     return callback err if err
            #     @syncCache (err) =>
            #         console.log "done syncCache"
                    # return callback err if err
            # @syncContacts (err) =>
                # console.log err
            callback err

#### Update 20150611

    testSyncContacts: (callback) ->

        @syncContacts (err, cozyContacts) ->
                if err
                    console.log 'err'
                    console.log err
                    return callback err

                console.log cozyContacts
                return callback cozyContacts


        # Test plugin :
        #
        #* liste de tous les contacts dirty <-- OK
        #* champs sourceId et SYNC2, 3
        #* update d'un contact (par id ...) (sans dirty à 1 ...)
        #* liste des contacts par sourceId . <-- OK

        ##
        # tester récupération de champs supplémentaires !!


        # # Add contact :
        # c = navigator.contacts.create
        #         displayName: "Super testeuh"
        #         name:  new ContactName "Super testeuh", "testeuh", "Super"
        #         sync2: 'yeeee'
        #         sync3: new Date().toISOString()
        #         sourceId: 'machintruec'
        #         dirty: 0

        # c.save (savedContact) ->
        #     console.log JSON.stringify savedContact, null, 2
        #     callback savedContact
        # , (err) ->
        #     console.log err
        #     callback err
        # , { accountType: 'io.cozy', accountName: 'myCozy', callerIsSyncAdapter: true }

        # options = new ContactFindOptions "1", true, [], 'io.cozy', 'myCozy'
        # # options = new ContactFindOptions "5d82f98d0cbf088c", true, [], 'com.google', 'guillaume.jacquart@gmail.com'

        # #fields = [navigator.contacts.fieldType.id]

        # fields = [navigator.contacts.fieldType.dirty]

        # navigator.contacts.find fields
        # , (contacts) ->

        #     console.log "CONTACTS FROM PHONE : #{contacts.length}"
        #     console.log contacts
        #     console.log JSON.stringify contacts[0], null, 2

        #     # contact = contacts[0]

        #     # contact.sync3 = "machintruc"
        #     # contact.sourceId = "spdifeuh"
        #     # contact.dirty = 0


        #     # contact.save callback, callback, { accountType: 'io.cozy', accountName: 'myCozy', callerIsSyncAdapter: true }

        #     callback contacts
        # , callback
        # , options


# "id": "4040",
#   "rawId": "3810",
#   "version": 3,

# "sourceId": "5d82f98d0cbf088c",
#   "dirty": false,
#   "sync1": "https://www.google.com/m8/feeds/contacts/guillaume.jacquart%40gmail.com/base2_property-android_linksto-gprofiles_highresphotos/5d82f98d0cbf088c",
#   "sync2": "\"Q3Y_eTVSLi17ImA9XRVTEkQIQwQ.\"",
#   "sync3": "2015-04-29T07:26:42.841Z",
#   "sync4": null


# {
#   "id": "4052",
#   "rawId": "3822",
#   "version": 2,
#   "displayName": "Dépannage électricité ERDF",
#   "name": {
#     "familyName": "Dépannage électricité ERDF",
#     "middleName": "",
#     "honorificPrefix": "",
#     "honorificSuffix": "",
#     "formatted": "  Dépannage électricité ERDF "
#   },
#   "nickname": null,
#   "phoneNumbers": [
#     {
#       "id": "3822",
#       "pref": false,
#       "value": "09 726 750 92",
#       "type": "other"
#     },
#     {
#       "id": "3829",
#       "pref": false,
#       "value": "09 726 750 92",
#       "type": "custom"
#     }
#   ],
#   "emails": null,
#   "addresses": null,
#   "ims": null,
#   "organizations": null,
#   "birthday": null,
#   "note": "",
#   "photos": null,
#   "categories": null,
#   "urls": null,
#   "sourceId": null,
#   "dirty": true,
#   "sync1": null,
#   "sync2": null,
#   "sync3": null,
#   "sync4": null
# }


####

    syncContacts: (callback) ->
        return callback null unless @config.get 'syncContacts'

        # Phone is right on conflict.
        # Contact sync has 3 phases
        # 1 - Phone2Pouch
        # 2 - Pouch <-> Couch (cozy)
        # 3 - Pouch2Phone.

        async.series [
            @_createAccount
            @_syncPhone2Pouch
            # @_syncWithCozy
            @_syncToCozy
            @_syncFromCozy
            @_syncPouch2Phone
            ], callback

    _createAccount: (callback) =>
        navigator.contacts.createAccount 'io.cozy', 'myCozy'
        , ->
            console.log 'create account success!!'
            callback null
        , (err) ->
            console.log 'create account err!!'
            console.log err
            callback err


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


    _syncFromCozy: (callback) =>
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
        replication.on 'error', callback
        replication.on 'complete', (result) =>
            console.log "REPLICATION COMPLETED contacts"
            console.log result
            app.replicator.config.save contactsPullCheckpointed: result.last_seq, callback

    saveContactInPhone: (cozyContact, phoneContact, callback) =>
        toSave = Contact.cozy2Cordova cozyContact

        if phoneContact
            toSave.id = phoneContact.id
            toSave.rawId = phoneContact.rawId

        options =
            accountType: 'io.cozy'
            accountName: 'myCozy'
            callerIsSyncAdapter: true

        toSave.save (contact)->
            callback null, contact
        , callback, options


    _syncPouch2Phone: (callback) ->
        # • SyncPouch2Phone
        # - pour les docs dont les revisions ne coincident pas / la liste de changements reçus ?
        # • update donnée dans phone

        # Get all phones and all Pouch contacts :
        # for each _id , check sync2  == _rev ;
        # if pouch > phone  ->
            # update in phone (callerIsSyncAdapter)
        # if == skip
        # else : error ! / skip.

        # Get contacts list
        async.parallel
            pouchContacts: (cb) ->
                app.replicator.db.query 'Contacts', { include_docs: true, attachments: true }, cb


            # Get all dirty contacts
            phoneContacts: (cb) ->
                navigator.contacts.find [navigator.contacts.fieldType.id]
                , (contacts) ->
                    console.log "CONTACTS FROM PHONE : #{contacts.length}"
                    console.log contacts

                    cb null, contacts


                , cb
                # TODO : required fields ?
                , new ContactFindOptions "", true, [], 'io.cozy', 'myCozy'
        , (err, res) ->
            return callback err if err

            phoneCById = Utils.array2Hash res.phoneContacts, 'sourceId'

            async.map res.pouchContacts.rows, (row, cb) ->
                pouchContact = row.doc
                id = pouchContact._id
                rev = pouchContact._rev

                unless id of phoneCById
                    return app.replicator.saveContactInPhone pouchContact, null, cb

                phoneContact = phoneCById[id]

                if rev > phoneContact.sync2
                    app.replicator.saveContactInPhone pouchContact, phoneContact, cb


                else if rev < phoneContact.sync2
                    # Error !!
                    console.log "Error, cozy late on rev !"
                    cb()
                else # nothing to do, skip
                    cb()


            , (err, updatedContacts) ->
                return callback err if err
                console.log "Done syncPouch2Phone"
                console.log updatedContacts
                callback null, updatedContacts




    _syncPouch2PhoneOld: (callback) ->
        # TODO: option : list of changed documents.
        console.log '_syncPouch2Phone'

        # Get contacts list
        async.parallel
            contacts: (cb) ->
                app.replicator.db.query 'Contacts', { include_docs: true, attachments: true }, cb
            syncInfos: (cb) ->
                # All docs but no design ones.
                app.replicator.contactsDB.query 'ByCozyContactId', { include_docs: true} , cb

        , (err, results) ->
            if err
                console.log err
                return callback err

            syncInfos = {}
            results.syncInfos.rows.forEach (row) ->
                doc = row.doc
                syncInfos[doc.pouchId] = doc

            async.eachSeries results.contacts.rows, (row, cb) =>
                cozyContact = row.doc

                if cozyContact._id of syncInfos # Contact already exists.
                    syncInfo = syncInfos[cozyContact._id]
                    # Mark as viewed to identify deleted contacts later.
                    delete syncInfos[cozyContact._id]

                    if syncInfo.pouchRev isnt cozyContact._rev
                        console.log '# Needs update !'
                        contact = Contact.cozy2Cordova cozyContact
                        contact.id = syncInfo.localId
                        contact.rawId = syncInfo.localRawId
                        app.replicator._saveContactOnPhone cozyContact, contact, syncInfo, cb

                    else
                        cb()

                else
                    console.log '# Not synced yet !'
                    contact = Contact.cozy2Cordova cozyContact
                    app.replicator._saveContactOnPhone cozyContact, contact, {}, cb

            , (err) ->
                    return callback err if err
                    # Remaining syncInfos are contact to delete from pouch.
                    toDelete = _.values syncInfos
                    console.log toDelete
                    async.eachSeries toDelete, \
                        app.replicator._deleteContactOnPhone, callback


    saveContactInPouch: (cozyContact, callback) ->
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

    _syncPhone2Pouch: (callback) =>

        # - pour tous les dirty :
        # * update donnée dans pouch
        # * update phone avec : màj rev, sourceId (si nouveau), ràz dirty.

        updateInPouch = (dirtyContact, cb) ->
            # Convert to pouch
            Contact.cordova2Cozy dirtyContact, (err, cozyContact) ->
                return cb err if err

                # Add in pouch
                app.replicator.saveContactInPouch cozyContact, (err, res) ->
                    return cb err if err
                    cozyContact._id = res.id
                    cozyContact._rev = res.rev

                    unDirty dirtyContact, cozyContact

            # get id (case create), rev, and put in phone while un-dirtying.
            unDirty = (dirtyContact, cozyContact) ->
                dirtyContact.dirty = false
                dirtyContact.sourceId = cozyContact._id
                dirtyContact.sync2 = cozyContact._rev

                dirtyContact.save () ->
                    cb null, cozyContact
                , cb
                ,
                    accountType: 'io.cozy'
                    accountName: 'myCozy'
                    callerIsSyncAdapter: true
            # done.

        # Get all dirty contacts
        navigator.contacts.find [navigator.contacts.fieldType.dirty]
        , (dirtyContacts) ->
            console.log "CONTACTS FROM PHONE : #{dirtyContacts.length}"
            console.log dirtyContacts

            async.map dirtyContacts, updateInPouch, callback


        , callback # quick fail on error.
        , new ContactFindOptions "1", true, [], 'io.cozy', 'myCozy'


    _syncPhone2PouchOld: (callback) =>
        # Get the contacts, and syncInfos.
        async.parallel [
            (cb) ->
                options = new ContactFindOptions "", true, [], 'io.cozy', 'myCozy'
                fields = [navigator.contacts.fieldType.id]

                navigator.contacts.find fields
                , (contacts) ->
                    console.log "CONTACTS FROM PHONE : #{contacts.length}"
                    cb null, contacts
                , cb
                , options
            (cb) ->
                # All docs but no design ones.
                app.replicator.contactsDB.query 'ByCozyContactId', { include_docs: true} , cb
            ],
            (err, results) ->
                [contacts, syncResults] = results
                syncInfos = {}
                console.log syncResults
                syncResults.rows.forEach (row) ->
                    doc = row.doc
                    syncInfos[doc.localId] = doc


                async.eachSeries contacts, (contact, cb) =>
                    console.log contact

                    if contact.id of syncInfos  # Contact already exists
                        syncInfo = syncInfos[contact.id]
                        # Mark as viewed to identify deleted contacts later.
                        delete syncInfos[contact.id]

                        if syncInfo.localRev isnt contact.version
                            console.log '# Phone2Pouch Needs update !'
                            app.replicator._saveContactInCozy contact, syncInfo, cb
                        else
                            cb()

                    else
                        console.log '# New contact from phone !'
                        app.replicator._saveContactInCozy contact, null, cb

                , (err) ->
                    return callback err if err
                    # Remaining syncInfos are contact to delete from pouch.
                    toDelete = _.values syncInfos
                    console.log toDelete
                    async.eachSeries toDelete, \
                        app.replicator._deleteContactInCozy, callback

    _deleteContactOnPhone: (syncInfo, callback) ->
        console.log "delete contact on Phone !"
        console.log syncInfo
        # delete contact in phone
        phoneContact = navigator.contacts.create { id: syncInfo.localId }

        phoneContact.remove -> # onSuccess
            # delete syncInfo object
            app.replicator.contactsDB.remove syncInfo, callback

        , callback # onError

    _deleteContactInCozy: (syncInfo, callback) ->
        console.log "delete contact in Cozy !"
        console.log syncInfo
        # delete contact in db
        # app.replicator.db.remove syncInfo.pouchId, syncInfo.pouchRev, (err, res) ->
        deletedContact =
            _id: syncInfo.pouchId
            _rev: syncInfo.pouchRev
            _deleted: true
            docType: 'contact'

        # app.replicator.db.get
        app.replicator.db.put deletedContact, \
            syncInfo.pouchId, syncInfo.pouchRev, \
            (err, res) ->
                return callback err if err

                # delete syncInfo object
                app.replicator.contactsDB.remove syncInfo, callback

    _saveContactInCozy: (contact, syncInfo, callback) =>
        Contact.cordova2Cozy contact, (err, cozyContact) =>
            doneCallback = (err, result) =>
                return cb err if err

                cozyContact._id = result.id
                cozyContact._rev = result.rev


                app.replicator._updateSyncInfo cozyContact, contact, syncInfo \
                    , callback

            if syncInfo?
                cozyContact._id = syncInfo.pouchId
                cozyContact._rev = syncInfo.pouchRev
                # TODO : clean up ! / avoid update pict on each update.
                if cozyContact?._attachments?.picture?
                    cozyContact._attachments.picture.revpos = syncInfo.pouchRev.split('-')[0] + 1

                app.replicator.db.put cozyContact, syncInfo.pouchId, \
                    syncInfo.pouchRev, doneCallback

            else
                # TODO : clean up !
                if cozyContact?._attachments?.picture?
                    cozyContact._attachments.picture.revpos = 1
                app.replicator.db.post cozyContact, doneCallback

    _saveContactOnPhone: (cozyContact, contact, syncInfo, callback) =>
        options =
            accountType: 'io.cozy'
            accountName: 'myCozy'

        onSuccess = (phoneContact) -> # onSuccess
            app.replicator._updateSyncInfo cozyContact, phoneContact, syncInfo, callback

        contact.save onSuccess, callback, options # onSuccess, onError, options.


    _updateSyncInfo: (cozyContact, contact, syncInfo, callback) =>
        syncInfo = syncInfo or {}
        _.extend syncInfo,
                pouchId: cozyContact._id
                pouchRev: cozyContact._rev
                localId: contact.id
                localRawId: contact.rawId
                localRev: contact.version

        if syncInfo._id?
            app.replicator.contactsDB.put syncInfo, \
                syncInfo._id, syncInfo._rev, callback

        else
            app.replicator.contactsDB.post syncInfo, callback

    syncContacts_old: (callback) ->
        return callback null unless @config.get 'syncContacts'

        console.log "SYNC CONTACTS"
        @set 'backup_step', 'contacts_scan'
        @set 'backup_step_done', null
        async.parallel [
            ImagesBrowser.getContactsList
            (cb) => @contactsDB.query 'ContactsByLocalId', {}, cb
        ], (err, result) =>
            return callback err if err
            [phoneContacts, rows: dbContacts] = result

            # for test purpose
            # phoneContacts = phoneContacts[0..50]

            console.log "BEGIN SYNC #{dbContacts.length} #{phoneContacts.length}"

            dbCache = {}
            dbContacts.forEach (row) ->
                dbCache[row.key] =
                    id: row.id
                    rev: row.value[1]
                    version: row.value[0]

            processed = 0
            @set 'backup_step_total', phoneContacts.length

            async.eachSeries phoneContacts, (contact, cb) =>
                @set 'backup_step_done', processed++


                contact.localId = contact.localId.toString()
                contact.docType = 'Contact'
                inDb = dbCache[contact.localId]

                log = "CONTACT : #{contact.localId} #{contact.localVersion}"
                log += "DB #{inDb?.version} : "

                # no changes
                if contact.localVersion is inDb?.version
                    console.log log + "NOTHING TO DO"
                    cb null

                # the contact already exists, but has changed, we update it
                else if inDb?
                    console.log log + "UPDATING"
                    @contactsDB.put contact, inDb.id, inDb.rev, cb

                # this is a new contact
                else
                    console.log log + "CREATING"
                    @contactsDB.post contact, (err, doc) ->
                        return callback err if err
                        return callback new Error('cant create') unless doc.ok
                        dbCache[contact.localId] =
                            id: doc.id
                            rev: doc.rev
                            version: contact.localVersion
                        cb null

            , (err) =>
                return callback err if err
                console.log "SYNC CONTACTS phone -> pouch DONE"

                # extract the ids
                ids = _.map dbCache, (doc) -> doc.id
                @set 'backup_step', 'contacts_sync'
                @set 'backup_step_total', ids.length

                replication = @contactsDB.replicate.to @config.remote,
                    since: 0, doc_ids: ids

                replication.on 'error', callback
                replication.on 'change', (e) =>
                    @set 'backup_step_done', e.last_seq
                replication.on 'complete', =>
                    callback null
                    # we query the view to force rebuilding the mapreduce index
                    @contactsDB.query 'ContactsByLocalId', {}, ->



    syncPictures: (force, callback) ->
        return callback null unless @config.get 'syncImages'

        console.log "SYNC PICTURES"
        @set 'backup_step', 'pictures_scan'
        @set 'backup_step_done', null
        async.series [
            @ensureDeviceFolder.bind this
            ImagesBrowser.getImagesList
            (callback) => @photosDB.query 'PhotosByLocalId', {}, callback
            (cb) => @db.query 'FilesAndFolder',
                {
                    startkey: ['/' + t 'photos']
                    endkey: ['/' + t('photos'), {}]
                } , cb
        ], (err, results) =>
            return callback err if err
            [device, images, rows: dbImages, dbPictures] = results

            dbImages = dbImages.map (row) -> row.key
            # We pick up the filename from the key to improve speed :
            # query without include_doc are 100x faster
            dbPictures = dbPictures.rows.map (row) -> row.key[1]?.slice 2

            myDownloadFolder = @downloads.toURL().replace 'file://', ''

            toUpload = []

            # Filter images : keep only the ones from Camera
            # TODO: Android Specific !
            images = images.filter (path) -> path.indexOf('/DCIM/') != -1

            if images.length is 0
                callback new Error 'no images in DCIM'

            # step 1 scan all images, find the new ones
            async.eachSeries images, (path, cb) =>
                #Check if pictures is in dbImages
                if path in dbImages
                    cb()
                else
                    # Check if pictures is already present (old installation)
                    fs.getFileFromPath path, (err, file) =>
                        # We test only on filename, case-insensitive
                        if file.name?.toLowerCase() in dbPictures
                            # Add photo in local database
                            @createPhoto path
                        else
                            # Create file
                            toUpload.push path

                        DeviceStatus.checkReadyForSync (err, ready, msg) ->
                            return cb err if err
                            return cb new Error msg unless ready

                            setTimeout cb, 1 # don't freeze UI


            , =>
                # step 2 upload one by one
                console.log "SYNC IMAGES : #{images.length} #{toUpload.length}"
                processed = 0
                @set 'backup_step', 'pictures_sync'
                @set 'backup_step_total', toUpload.length
                async.eachSeries toUpload, (path, cb) =>
                    @set 'backup_step_done', processed++
                    console.log "UPLOADING #{path}"
                    @uploadPicture path, device, (err) =>
                        console.log "ERROR #{path} #{err}" if err
                        DeviceStatus.checkReadyForSync (err, ready, msg) ->
                            return cb err if err
                            return cb new Error msg unless ready

                            setTimeout cb, 1 # don't freeze UI.

                , callback

    uploadPicture: (path, device, callback) ->
        fs.getFileFromPath path, (err, file) =>
            return callback err if err

            fs.contentFromFile file, (err, content) =>
                return callback err if err

                @createBinary content, file.type, (err, bin) =>
                    return callback err if err

                    @createFile file, path, bin, device, (err, res) =>
                        return callback err if err

                        @createPhoto path, callback


    createBinary: (blob, mime, callback) ->
        @config.remote.post docType: 'Binary', (err, doc) =>
            return callback err if err
            return callback new Error('cant create binary') unless doc.ok

            @config.remote.putAttachment doc.id, 'file', doc.rev, blob, mime, (err, doc) =>
                return callback err if err
                return callback new Error('cant attach') unless doc.ok
                callback null, doc

    createFile: (cordovaFile, localPath, binaryDoc, device, callback) ->
        dbFile =
            docType          : 'File'
            localPath        : localPath
            name             : cordovaFile.name
            path             : "/" + t('photos')
            class            : @fileClassFromMime cordovaFile.type
            lastModification : new Date(cordovaFile.lastModified).toISOString()
            creationDate     : new Date(cordovaFile.lastModified).toISOString()
            size             : cordovaFile.size
            tags             : ['from-' + @config.get 'deviceName']
            binary: file:
                id: binaryDoc.id
                rev: binaryDoc.rev

        @config.remote.post dbFile, callback

    createPhoto: (localPath, callback) ->
        dbPhoto =
            docType : 'Photo'
            localId: localPath
        @photosDB.post dbPhoto, callback

    fileClassFromMime: (type) ->
        return switch type.split('/')[0]
            when 'image' then "image"
            when 'audio' then "music"
            when 'video' then "video"
            when 'text', 'application' then "document"
            else "file"

    ensureDeviceFolder: (callback) ->
        findDevice = (id, callback) =>
            @db.get id, (err, res) ->
                if not err?
                    callback()
                else
                    findDevice id, callback

        createNew = () =>
            console.log "MAKING ONE"
            # no device folder, lets make it
            folder =
                docType          : 'Folder'
                name             : t 'photos'
                path             : ''
                lastModification : new Date().toISOString()
                creationDate     : new Date().toISOString()
                tags             : []
            options =
                key: ['', "1_#{folder.name.toLowerCase()}"]
            @config.remote.post folder, (err, res) =>
                app.replicator.startRealtime()
                # Wait to receive folder in local database
                findDevice res.id, () ->
                    return callback err if err
                    callback null, folder

        @db.query 'FilesAndFolder', key: ['', "1_#{t('photos').toLowerCase()}"], (err, results) =>
            return callback err if err
            if results.rows.length > 0
                device = results.rows[0]
                console.log "DEVICE FOLDER EXISTS"
                return callback null, device
            else
                # TODO : relies on byFullPath folder view of cozy-file !
                query = '/_design/folder/_view/byfullpath/?' +
                    "key=\"/#{t('photos')}\""

                request.get @config.makeUrl(query), (err, res, body) ->
                    return callback err if err
                    if body?.rows?.length is 0
                        createNew()
                    else
                        # already exist remote, but not locally...
                        callback new Error 'photo folder not replicated yet'
