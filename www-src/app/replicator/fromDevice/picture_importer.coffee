async = require 'async'
PictureHandler = require '../../lib/android_picture_handler'
PictureFolderHandler = require '../../lib/android_picture_folder_handler'
fs = require '../filesystem'
request = require '../../lib/request'
DeviceStatus = require '../../lib/device_status'
log = require('../../lib/persistent_log')
    prefix: "PictureImporter"
    date: true

module.exports = class PictureImporter

    constructor: (@config, @dbLocal, @pictureHandler, @pictureFolderHandler) ->
        @config ?= app.replicator.config
        @deviceName = @config.get 'deviceName'
        @devicePassword = @config.get 'devicePassword'
        @dbLocal ?= app.replicator.photosDB
        @pictureHandler ?= new PictureHandler()
        @pictureFolderHandler ?= new PictureFolderHandler()

    synchronize: (callback) ->
        log.info "synchronize"

        async.series [
            (next) => @pictureFolderHandler.getOrCreate next
            (next) => @pictureHandler.getAllPath next
            (next) => @pictureHandler.getSynchronizedPicturesInLocal next
            (next) => @pictureHandler.getSynchronizedPicturesInRemote next
        ], (err, [folderIsCreated, paths, syncLocal, syncRemote]) =>
            return callback err if err

            # Don't stop on some errors, but keep them to display them.
            errors = []
            toUpload = []

            async.eachSeries paths, (path, next) =>
                return next() if path in syncLocal

                fileName = path.toLowerCase().replace /^.*[\\\/]/, ''
                if fileName in syncRemote
                    @pictureHandler.saveInLocal path
                else
                    toUpload.push path

                @_check next
            , (err) =>
                return callback err if err

                total = paths.length
                uploaded = total - toUpload.length
                log.info "Uploaded pictures: #{uploaded}/#{total}"

                async.eachSeries toUpload, (path, next) =>
                    @_uploadPicture path, (err) =>
                        log.info path
                        if err
                            log.error err
                            err.message = err.message + ' - ' + path
                            errors.push err
                        else
                            uploaded++
                            log.info "Uploaded pictures: #{uploaded}/#{total}"

                        @_check next
                , (err) ->
                    return callback err if err

                    if errors.length > 0
                        messages = (errors.map (err) -> err.message).join '; '
                        return callback new Error messages

                    callback()


    _uploadPicture: (path, callback) ->
        log.info "_uploadPicture, path: #{path}"

        fs.getFileFromPath path, (err, file) =>
            return callback err if err

            @_createFile file, path, (err, res, body) =>
                return callback err if err

                @_createBinary file, body._id, (err) =>
                    return callback err if err

                    @_createPhoto path, callback


    _createFile: (file, path, callback) ->
        log.info "_createFile"

        dbFile =
            docType          : 'File'
            localPath        : path
            name             : file.name
            path             : "/" + t 'photos'
            class            : @_fileClassFromMime file.type
            mime             : file.type
            lastModification : new Date(file.lastModified).toISOString()
            creationDate     : new Date(file.lastModified).toISOString()
            size             : file.size
            tags             : ['from-' + @config.deviceName]

        options = @config.makeDSUrl "/data/"
        options.body = dbFile

        request.post options, callback


    _createBinary: (file, fileId, callback) ->
        log.info "_createBinary"

        # Standard Blob isn't available on android prior to 4.3 ,
        # and FormData doesn't work on 4.0 , so we use FileTransfert plugin.
        if window.device.version? < '4.3'
            @_createBinaryWFiltTransfert file, fileId, callback

        else
            fs.getFileAsBlob file, (err, content) =>
                return callback err if err
                @_createBinaryWFormData content, fileId, callback


    _createPhoto: (path, callback) ->
        log.info "_createPhoto"

        dbPhoto =
            docType : 'Photo'
            localId: path
        @dbLocal.post dbPhoto, callback

    _createBinaryWFiltTransfert: (file, fileId, callback) ->
        log.info "_createBinaryWFiltTransfert"

        options = @config.makeDSUrl "/data/#{fileId}/binaries/"
        options.fileName = 'file'
        options.mimeType = file.type
        options.headers = @_getHeaders()
        ft = new FileTransfer()
        ft.upload file.localURL, options.url, callback, (-> callback())
        , options


    _createBinaryWFormData: (blob, fileId, callback) ->
        log.info "_createBinaryWFormData"

        options = @config.makeDSUrl "/data/#{fileId}/binaries/"
        data = new FormData()
        data.append 'file', blob, 'file'
        $.ajax
            type: 'POST'
            url: options.url
            headers: @_getHeaders()
            username: @deviceName
            password: @devicePassword
            data: data
            contentType: false
            processData: false
            success: (success) -> callback null, success
            error: callback

    _fileClassFromMime: (type) ->
        log.info "_fileClassFromMime"

        switch type.split('/')[0]
            when 'image' then "image"
            when 'audio' then "music"
            when 'video' then "video"
            when 'text', 'application' then "document"
            else "file"

    _check: (callback) ->
        log.info "_check"

        DeviceStatus.checkReadyForSync (err, ready, msg) ->
            return callback err if err
            return callback new Error msg unless ready

            window.setImmediate callback # don't freeze UI

    _getHeaders: ->
        'Authorization': 'Basic ' + btoa unescape encodeURIComponent \
            "#{@deviceName}:#{@devicePassword}"
