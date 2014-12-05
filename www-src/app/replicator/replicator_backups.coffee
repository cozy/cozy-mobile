DeviceStatus = require '../lib/device_status'
fs = require './filesystem'


# This files contains all replicator functions liked to backup
# use the ImagesBrowser cordova plugin to fetch images & contacts
# from phone.
# Set the inBackup attribute to true while a backup is in progress
# Set the backup_step attribute with value in
# [contacts_scan, pictures_sync, contacts_sync]
# For each step, hint of progress are in backup_step_done and backup_step_total

module.exports =

    # wrapper around _backup to maintain the state of inBackup
    backup: (callback = ->) ->
        return callback null if @get 'inBackup'
        @set 'inBackup', true
        @set 'backup_step', null
        @liveReplication?.cancel()
        @_backup (err) =>
            @set 'backup_step', null
            @set 'inBackup', false
            @startRealtime()
            return callback err if err
            @config.save lastBackup: new Date().toString(), (err) =>
                callback null


    _backup: (callback) ->
        DeviceStatus.checkReadyForSync (err, ready, msg) =>
            console.log "SYNC STATUS", err, ready, msg
            return callback err if err
            return callback new Error(t msg) unless ready
            console.log "WE ARE READY FOR SYNC"

            @syncPictures (err) =>
                return callback err if err
                @syncContacts (err) =>
                    callback err


    syncContacts: (callback) ->
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



    syncPictures: (callback) ->
        return callback null unless @config.get 'syncImages'

        console.log "SYNC PICTURES"
        @set 'backup_step', 'pictures_scan'
        @set 'backup_step_done', null
        async.series [
            @ensureDeviceFolder.bind this
            ImagesBrowser.getImagesList
            (cb) => @photosDB.query 'PhotosByLocalId', {}, cb
        ], (err, results) =>

            return callback err if err
            [device, images, rows: dbImages] = results

            console.log "SYNC IMAGES : #{images.length} #{dbImages.length}"

            dbImages = dbImages.map (row) -> row.key

            myDownloadFolder = @downloads.toURL().replace 'file://', ''

            toUpload = []

            # step 1 scan all images, find the new ones
            async.eachSeries images, (path, cb) ->

                unless path in dbImages
                    toUpload.push path

                setTimeout cb, 1

            , =>
                # step 2 upload one by one
                processed = 0
                @set 'backup_step', 'pictures_sync'
                @set 'backup_step_total', toUpload.length
                async.eachSeries toUpload, (path, cb) =>
                    @set 'backup_step_done', processed++
                    console.log "UPLOADING #{path}"
                    @uploadPicture path, device, (err) ->
                        console.log "ERROR #{path} #{err}" if err
                        setTimeout cb, 1

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
                # see ./main#createRemotePouchInstance
                delete @config.remoteHostObject.headers['Content-Type']
                callback null, doc

    createFile: (cordovaFile, localPath, binaryDoc, device, callback) ->
        dbFile =
            docType          : 'File'
            localPath        : localPath
            name             : cordovaFile.name
            path             : device.path + '/' + device.name
            class            : @fileClassFromMime cordovaFile.type
            lastModification : new Date(cordovaFile.lastModified).toISOString()
            creationDate     : new Date(cordovaFile.lastModified).toISOString()
            size             : cordovaFile.size
            tags             : ['uploaded-from-' + @config.get 'deviceName']
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

        createNew = (number=0) =>
            console.log "MAKING ONE"
            # no device folder, lets make it
            folder =
                docType          : 'Folder'
                name             : @config.get 'deviceName'
                path             : ''
                lastModification : new Date().toISOString()
                creationDate     : new Date().toISOString()
                tags             : []
            if number isnt 0
                folder.name = @config.get('deviceName') + '-' + number
            options =
                key: ['', "1_#{folder.name.toLowerCase()}"]
            @db.query 'FilesAndFolder', options, (err, folders) =>
                if folders.rows.length is 0
                    @config.remote.post folder, (err, res) =>
                        dbDevice =
                            docType : 'Device'
                            localId: res.id
                        @photosDB.post dbDevice, (err, res) =>
                            app.replicator.startRealtime()
                            # Wait to receive folder in local database
                            findDevice dbDevice.localId, () ->
                                return callback err if err
                                callback null, folder
                else
                    createNew(number + 1)

        @photosDB.query 'DevicesByLocalId', {}, (err, results) =>
            return callback err if err
            if results.rows.length > 0
                device = results.rows[0]
                @db.get device.key, (err, res) ->
                    if err?
                        createNew()
                        @photosDB.remove device.value
                    else
                        console.log "DEVICE FOLDER EXISTS"
                        console.log res
                        return callback null, res
            else
                createNew()