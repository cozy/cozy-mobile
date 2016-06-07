async = require 'async'
DeviceStatus = require '../lib/device_status'
DesignDocuments = require './design_documents'
fs = require './filesystem'
toast = require '../lib/toast'


log = require('../lib/persistent_log')
    prefix: "replicator backup"
    date: true

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

        try
            @set 'inBackup', true
            @set 'backup_step', null
            @_backup (err) =>
                @set 'backup_step', null
                @set 'backup_step_done', null
                @set 'inBackup', false
        catch e
            log.error "Error in backup: ", e

        callback()


    _backup: (callback) ->
        DeviceStatus.checkReadyForSync (err, ready, msg) =>
            log.info "SYNC STATUS", err, ready, msg
            return callback err if err
            unless ready
                log.warn msg
                toast.info msg
                return callback()
            log.info "WE ARE READY FOR SYNC"

            # async series with non blocking errors
            errors = []
            async.series [
                (cb) =>
                    @syncPictures (err) =>
                        if err and err.message isnt "no images in DCIM"
                            log.error "in syncPictures: ", err
                            errors.push err
                            return cb()

                        # Avoid saving while in a change config state.
                        if app.init.currentState.indexOf('c') isnt 0
                            @config.set 'lastBackup', Date.now(), cb

                        else
                            cb()

                (cb) =>
                    DeviceStatus.checkReadyForSync (err, ready, msg) =>
                        unless ready or err
                            err = new Error msg
                        return cb err if err

                        @syncCache (err) ->
                            if err
                                log.error "in syncCache", err
                                errors.push err
                            cb()
            ], (err) ->
                return callback err if err

                if errors.length > 0
                    callback errors[0]
                else
                    callback()

    # Upload photos take with device on the cozy.
    # 1. check device folder
    # 2. Get list of image from android (--> images)
    # 3. Get list of already added image from this device (photoDB -> dbImages)
    # 4. Get list of files in t'photos' folder (--> dbPictures).
    # 5. For each images from android :
    # 5.1 - skip images already uploaded (in photoDB)
    # 5.2 - image already present on cozy : then flag it (add to photoDB)
    # 5.3 - add to upload list
    # 6. Upload image list
    # 6.1 create File document in Cozy
    # 6.2 create Ninary document in Cozy
    # 6.3 add to PhotoDB
    syncPictures: (callback) ->
        log.debug "syncPictures"

        return callback null unless @config.get 'syncImages'

        log.info "sync pictures"
        @set 'backup_step', 'pictures_scan'
        @set 'backup_step_done', null

        async.series [
            @ensureDeviceFolder.bind this
            ImagesBrowser.getImagesList
            (cb) => @photosDB.query DesignDocuments.PHOTOS_BY_LOCAL_ID, {}, cb
            (cb) => @db.query DesignDocuments.FILES_AND_FOLDER,
                {
                    startkey: ['/' + t 'photos']
                    endkey: ['/' + t('photos'), {}]
                } , cb
        ], (err, results) =>
            return callback err if err
            [device, images, {rows: dbImages}, dbPictures] = results

            dbImages = dbImages.map (row) -> row.key
            # We pick up the filename from the key to improve speed :
            # query without include_doc are 100x faster
            dbPictures = dbPictures.rows.map (row) -> row.key[1]?.slice 2

            myDownloadFolder = @downloads.toURL().replace 'file://', ''

            toUpload = []

            # Filter images : keep only the ones from Camera
            # TODO: Android Specific !
            images = images.filter (path) ->
                return path? and path.indexOf('/DCIM/') isnt -1

            # Filter pathes with ':' (colon), as cordova plugin won't pick them
            # especially ':nopm:' ending files,
            # which may be google+ 's NO Photo Manager
            images = images.filter (path) -> path.indexOf(':') is -1

            if images.length is 0
                return callback new Error 'no images in DCIM'

            # Don't stop on some errors, but keep them to display them.
            errors = []
            # step 1 scan all images, find the new ones
            async.eachSeries images, (path, cb) =>
                #Check if pictures is in dbImages
                if path in dbImages
                    cb()

                else
                    # Check if pictures is already present (old installation)

                    fs.getFileFromPath path, (err, file) =>
                        if err
                            err.message = err.message + ' - ' + path
                            log.info err
                            errors.push err # store the error for future display
                            return cb() # continue

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

                            setImmediate cb # don't freeze UI


            , (err) =>
                return callback err if err
                # step 2 upload one by one
                log.info "SYNC IMAGES : #{images.length} #{toUpload.length}"
                processed = 0
                @set 'backup_step', 'pictures_sync'
                @set 'backup_step_total', toUpload.length
                async.eachSeries toUpload, (path, cb) =>
                    @set 'backup_step_done', processed++
                    log.info "UPLOADING #{path}"
                    @uploadPicture path, device, (err) ->
                        if err
                            log.error "ERROR #{path}"
                            log.error err
                            err.message = err.message + ' - ' + path
                            errors.push err

                        DeviceStatus.checkReadyForSync (err, ready, msg) ->
                            return cb err if err
                            if ready
                                setImmediate cb  # don't freeze UI.
                            else
                                # stop uploading if leaves wifi and ...
                                cb new Error msg

                , (err) ->
                    return callback err if err
                    if errors.length > 0
                        messages = (errors.map (err) -> err.message).join '; '
                        return callback new Error messages

                    callback()


    uploadPicture: (path, device, callback) ->
        log.debug "uploadPicture"

        fs.getFileFromPath path, (err, file) =>
            return callback err if err
            @createFile file, path, device, (err, res, body) =>
                return callback err if err
                @createBinary file, body._id, (err) =>
                    return callback err if err
                    @createPhoto path, callback


    createBinary: (file, fileId, callback) ->
        log.debug "createBinary"

        # Standard Blob isn't available on android prior to 4.3 ,
        # and FormData doesn't work on 4.0 , so we use FileTransfert plugin.
        if device.version? and device.version < '4.3'
            @createBinaryWFiltTransfert file, fileId, callback

        else
            fs.getFileAsBlob file, (err, content) =>
                return callback err if err
                @createBinaryWFormData content, fileId, callback


    createBinaryWFiltTransfert: (file, fileId, callback) ->
        log.debug "createBinaryWFiltTransfert"

        options = @requestCozy.getDataSystemOption "/data/#{fileId}/binaries/"
        options.fileName = 'file'
        options.mimeType = file.type
        options.headers =
            'Authorization': 'Basic ' +
                btoa unescape encodeURIComponent(
                    @config.get('deviceName') + ':' +
                    @config.get('devicePassword'))

        ft = new FileTransfer()
        ft.upload file.localURL, options.url, callback, (-> callback())
        , options


    createBinaryWFormData: (blob, fileId, callback) ->
        log.debug "createBinaryWFormData"

        data = new FormData()
        data.append 'file', blob, 'file'
        $.ajax
            type: 'POST'
            url: @requestCozy.getDataSystemUrl "/data/#{fileId}/binaries/"
            headers:
                'Authorization': 'Basic ' +
                            btoa(@config.get('deviceName') + ':' +
                                @config.get('devicePassword'))
            username: @config.get 'deviceName'
            password: @config.get 'devicePassword'
            data: data
            contentType: false
            processData: false
            success: (success) -> callback null, success
            error: callback


    createFile: (cordovaFile, localPath, device, callback) ->
        log.debug "createFile"

        dbFile =
            docType          : 'File'
            localPath        : localPath
            name             : cordovaFile.name
            path             : "/" + t('photos')
            class            : @fileClassFromMime cordovaFile.type
            mime             : cordovaFile.type
            lastModification : new Date(cordovaFile.lastModified).toISOString()
            creationDate     : new Date(cordovaFile.lastModified).toISOString()
            size             : cordovaFile.size
            tags             : ['from-' + @config.get 'deviceName']

        options =
            method: 'post'
            type: 'data-system'
            path: '/data'
            body: dbFile
        @requestCozy.request options, callback


    createPhoto: (localPath, callback) ->
        log.debug "createPhoto"

        dbPhoto =
            docType : 'Photo'
            localId: localPath
        @photosDB.post dbPhoto, callback


    fileClassFromMime: (type) ->
        log.debug "fileClassFromMime"

        switch type.split('/')[0]
            when 'image' then "image"
            when 'audio' then "music"
            when 'video' then "video"
            when 'text', 'application' then "document"
            else "file"


    ensureDeviceFolder: (callback) ->
        log.debug "ensureDeviceFolder"

        findFolder = (id, cb) =>
            @db.get id, (err, res) ->
                if not err?
                    cb()
                else
                    # Busy waiting for device folder creation
                    setTimeout (-> findFolder id, cb ), 200

        # Creates 'photos' folder in cozy, and wait for its creation.
        createNew = () =>
            log.info "creating 'photos' folder"
            # no Photos folder, lets make it
            folder =
                docType          : 'Folder'
                name             : t 'photos'
                path             : ''
                lastModification : new Date().toISOString()
                creationDate     : new Date().toISOString()
                tags             : []

            options =
                method: 'post'
                type: 'data-system'
                path: '/data'
                body: folder
            @requestCozy.request options, (err, result, body) ->
                return callback err if err
                # Wait to receive folder in local database
                findFolder body._id, () ->
                    return callback err if err
                    callback null, folder

        options = key: ['', "1_#{t('photos').toLowerCase()}"]
        @db.query DesignDocuments.FILES_AND_FOLDER, options, (err, results) =>
            return callback err if err
            if results.rows.length > 0
                device = results.rows[0]
                log.info "DEVICE FOLDER EXISTS"
                return callback null, device
            else
                options =
                    method: 'post'
                    type: 'data-system'
                    path: '/request/folder/byfullpath/'
                    body:
                        key: t('photos')
                @requestCozy.request options, (err, res, docs) ->
                    return callback err if err
                    if docs?.length is 0
                        createNew()
                    else
                        # should not reach here: already exist remote, but not
                        # present in replicated @db ...
                        callback new Error 'photo folder not replicated yet'

