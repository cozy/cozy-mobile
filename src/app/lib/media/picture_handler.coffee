async = require 'async'
ConnectionHandler = require '../connection_handler'
fs = require '../../replicator/filesystem'
path = require 'path'
DesignDocuments = require '../../replicator/design_documents'
MediaUploader = require './media_uploader'
Permission = require '../permission'
log = require('../persistent_log')
    prefix: 'PictureHandler'
    date: true


instance = null


module.exports = class PictureHandler


    constructor: (@media) ->
        return instance if instance
        instance = @

        _.extend @, Backbone.Events

        @localDb ?= app.init.database.localDb
        @replicateDb ?= app.init.database.replicateDb
        @remoteDb ?= app.init.database.remoteDb
        @media ?= new MediaUploader()
        @connectionHandler ?= new ConnectionHandler()
        @requestCozy ?= app.init.requestCozy
        @queue = 0
        @permission = new Permission()


    upload: (callback) ->
        @_findLocalPicturesPath (err, picturesPath) =>
            return callback err if err

            async.series [
                (cb) => @_ensureDeviceFolder cb
                (cb) => @_removeOldPicturesOnCache picturesPath, cb
                (cb) => @_saveNewPicturesOnCache picturesPath, cb
                (cb) => @_findPicturesOnCache cb
                (cb) => @_findPicturesOnCozy cb
            ], (err, result) =>
                return callback err if err

                picturesCache = result[3]
                picturesCache = picturesCache.filter (pictureCache) ->
                    !pictureCache.value.binaryExist
                return callback() if picturesCache.length is 0
                @_setQueue picturesCache.length

                cozyFiles = {}
                for cozyFile in result[4].rows
                    fileName = cozyFile.key[1].substr(2).toLowerCase()
                    cozyFiles[fileName] = cozyFile

                async.eachSeries picturesCache, (pictureCache, cb) =>
                    async.series [
                        (cb) => @_uploadCozyFile pictureCache, cozyFiles, cb
                        (cb) => @_uploadCozyBinary pictureCache, cb
                        (cb) => @_checkCozyBinary pictureCache, cb
                    ], (err) =>
                        log.warn err if err
                        @_setQueue --@queue
                        cb()
                , (err) =>
                    log.warn err if err
                    @_setQueue 0
                    callback()


    _checkCozyBinary: (pictureCache, callback) ->
        pictureValue = pictureCache.value
        return callback() if pictureValue.binaryExist or !pictureValue.binaryId

        @media.checkBinary pictureValue.binaryId, (err, binaryExist) =>
            if binaryExist
                data = binaryExist: binaryExist
            else
                data = binaryId: false

            @_updateCache pictureCache.id, data, callback


    _uploadCozyBinary: (pictureCache, callback) ->
        pictureValue = pictureCache.value
        return callback() if pictureValue.binaryId or not pictureValue.fileId

        @remoteDb ?= app.init.database.remoteDb
        @remoteDb.get pictureValue.fileId, (err, cozyFile) =>
            return callback err if err

            setBinaryId = (binaryId) =>
                @_updateCache pictureCache.id, binaryId: binaryId, (err) ->
                    return callback err if err
                    pictureCache.value.binaryId = binaryId
                    callback null, pictureCache

            binaryId = cozyFile.binary?.file?.id
            return setBinaryId binaryId if binaryId

            fs.getFileFromPath pictureCache.key, (err, file) =>
                return callback err if err

                @media.uploadBinary file, cozyFile._id, (err) =>
                    return callback err if err

                    @remoteDb.get cozyFile._id, (err, cozyFile) ->
                        return callback err if err

                        setBinaryId cozyFile.binary?.file?.id


    _uploadCozyFile: (pictureCache, cozyFiles, callback) ->
        return callback() if pictureCache.value.fileId

        setFileId = (fileId) =>
            @_updateCache pictureCache.id, fileId: fileId, (err) ->
                return callback err if err
                pictureCache.value.fileId = fileId
                callback null, pictureCache

        fileName = path.parse(pictureCache.key).base.toLowerCase()
        if cozyFiles[fileName] isnt undefined
            setFileId cozyFiles[fileName].id
        else
            @_createFile pictureCache.key, (err, fileId) ->
                return callback err if err
                setFileId fileId



    _findPicturesOnCozy: (callback) ->
        options =
            startkey: ['/' + t 'photos']
            endkey: ['/' + t('photos'), {}]
        @replicateDb.query DesignDocuments.FILES_AND_FOLDER, options, callback



    ############
    ### File
    ###


    _findLocalPicturesPath: (callback) ->

        success = ->
            ImagesBrowser.getImagesList (err, pictures) ->
                if pictures
                    if device.platform is 'Android'

                        # Filter images : keep only the ones from Camera
                        pictures = pictures.filter (picturePath) ->
                            picturePath? and \
                                    picturePath.indexOf('/DCIM/') isnt -1

                    # Filter pathes with ':' (colon), as cordova plugin won't
                    # pick them especially ':nopm:' ending files,
                    # which may be google+ 's NO Photo Manager
                    pictures = pictures.filter (picturePath) ->
                        picturePath.indexOf(':') is -1

                callback err, pictures

        @permission.checkPermission 'files', success, (err) ->
            callback err, []


    _createFile: (picturePath, callback) ->
        cozyPath = "/#{t 'photos'}"

        fs.getFileFromPath picturePath, (err, file) =>
            return callback err if err
            @media.createFile file, picturePath, cozyPath, callback



    ###############
    ### Local cache
    ###

    _removeOldPicturesOnCache: (picturesPath, callback) ->
        @_findPicturesOnCache (err, cachePictures) =>
            return callback err if err

            oldCache = cachePictures.filter (cachePicture) ->
                cachePicture.key not in picturesPath

            async.eachSeries oldCache, (cachePicture, cb) =>
                @_deleteCache cachePicture.id, cb
            , callback


    _saveNewPicturesOnCache: (picturesPath, callback) ->
        @_findPicturesOnCache (err, cachePictures) =>
            return callback err if err

            picturesCacheOrdered = {}
            for pictureCache in cachePictures
                picturesCacheOrdered[pictureCache.key] = pictureCache

            picturesPathFiltered = picturesPath.filter (picturePath) ->
                picturesCacheOrdered[picturePath] is undefined

            async.eachSeries picturesPathFiltered, (picturePath, cb) =>
                return @_createCache picturePath, cb
            , callback


    _deleteCache: (pictureId, callback) ->
        @localDb.get pictureId, (err, cachePicture) =>
            return callback err if err

            @localDb.remove cachePicture, callback


    _createCache: (picturePath, callback) ->
        cachePicture =
            docType : 'Photo'
            localId: picturePath

        @localDb.post cachePicture, callback


    _updateCache: (pictureId, data, callback) ->
        @localDb.get pictureId, (err, cachePicture) =>
            return callback err if err

            if data
                for key, value of data
                    cachePicture[key] = value

            @localDb.put cachePicture, callback


    _findPicturesOnCache: (callback) ->
        @localDb.query DesignDocuments.PHOTOS_BY_LOCAL_ID, {}, (err, result) ->
            return callback err if err
            cachePictures = result.rows
            callback null, cachePictures


    _setQueue: (@queue) ->
        @trigger "change:queue", @, @queue


    _ensureDeviceFolder: (callback) ->
        findFolder = (id, cb) =>
            @replicateDb.get id, (err, result) ->
                if not err? and result.rows isnt undefined
                    cb null, result.rows[0]
                else
                    # Busy waiting for device folder creation
                    setTimeout (-> findFolder id, cb ), 1000

        designId = DesignDocuments.FILES_AND_FOLDER
        options = key: ['', "1_#{t('photos').toLowerCase()}"]
        @replicateDb.query designId, options, (err, results) =>
            return callback err if err

            if results.rows.length > 0
                folder = results.rows[0]
                callback null, folder
            else
                options =
                    method: 'post'
                    type: 'data-system'
                    path: '/request/folder/byfullpath/'
                    retry: 3
                    body:
                        key: t 'photos'

                @requestCozy.request options, (err, res, docs) =>
                    return callback err if err

                    if docs?.length is 0
                        @media.createFolder t('photos'), '', (err, id) ->
                            return callback err if err

                            # Wait to receive folder in local database
                            findFolder id, (err, folder) ->
                                return callback err if err

                                callback null, folder
                    else
                        # should not reach here: already exist remote, but not
                        # present in replicated @replicateDb ...
                        callback new Error 'photo folder not replicated yet'
