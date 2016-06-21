PictureHandler = require './picture_handler'
fs = require '../../replicator/filesystem'
DeviceStatus = require '../device_status'
ConnectionHandler = require '../connection_handler'
log = require('../persistent_log')
    prefix: 'MediaUploader'
    date: true


instance = null


module.exports = class MediaUploader


    constructor: ->
        return instance if instance
        instance = @

        @pictureHandler ?= new PictureHandler @
        @config ?= app.init.config
        @requestCozy ?= app.init.requestCozy
        @connectionHandler = new ConnectionHandler()


    upload: (callback) ->
        log.debug 'upload'

        if @_isUploadable()
            @pictureHandler.upload callback
        else
            callback()


    checkBinary: (binaryId, callback) ->
        options =
            method: 'get'
            type: 'data-system'
            path: "/data/exist/#{binaryId}"
            retry: 3

        @requestCozy.request options, (err, res, body) ->
            return callback err if err
            callback null, body.exist


    uploadBinary: (file, fileId, callback) ->
        log.debug "uploadBinary"

        return callback() unless @_isUploadable()

        DeviceStatus.checkReadyForSync (err, ready, msg) =>
            return callback() unless ready

            path = "/data/#{fileId}/binaries/"

            # Standard Blob isn't available on android prior to 4.3 ,
            # and FormData doesn't work on 4.0 , so we use FileTransfert plugin.
            if device.version? and device.version < '4.3'

                options = @requestCozy.getDataSystemOption path
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

            else

                fs.getFileAsBlob file, (err, blob) =>
                    return callback err if err

                    url = @requestCozy.getDataSystemUrl path
                    data = new FormData()
                    data.append 'file', blob, 'file'
                    $.ajax
                        type: 'POST'
                        url: url
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


    createFile: (cordovaFile, localPath, cozyPath, callback) ->
        log.debug "createFile"

        fileClassFromMime = (type) ->
            switch type.split('/')[0]
                when 'image' then "image"
                when 'audio' then "music"
                when 'video' then "video"
                when 'text', 'application' then "document"
                else "file"

        dbFile =
            docType          : 'File'
            localPath        : localPath
            name             : cordovaFile.name
            path             : cozyPath
            class            : fileClassFromMime cordovaFile.type
            mime             : cordovaFile.type
            lastModification : new Date(cordovaFile.lastModified).toISOString()
            creationDate     : new Date(cordovaFile.lastModified).toISOString()
            size             : cordovaFile.size
            tags             : ['from-' + @config.get 'deviceName']

        @_sendFileOrFolder dbFile, callback


    createFolder: (name, path, callback) ->
        log.debug "createFolder"

        dbFolder =
            docType          : 'Folder'
            name             : name
            path             : path
            lastModification : new Date().toISOString()
            creationDate     : new Date().toISOString()
            tags             : ['from-' + @config.get 'deviceName']

        @_sendFileOrFolder dbFolder, callback


    _sendFileOrFolder: (doc, callback) ->
        options =
            method: 'post'
            type: 'data-system'
            path: '/data'
            body: doc
            retry: 3

        @requestCozy.request options, (err, result, body) ->
            return callback err if err

            unless result.status is 201
                log.debug result
                return callback new Error "Status code is not 201."

            callback null, body._id


    _isUploadable: ->
        return false unless @config.get 'syncImages'
        @connectionHandler.isWifi() or not @config.get 'syncOnWifi'
