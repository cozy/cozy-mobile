async = require 'async'
DesignDocuments = require '../replicator/design_documents'
fs = require '../replicator/filesystem'
log = require('./persistent_log')
    prefix: "FileCacheHandler"
    date: true


instance = null


module.exports = class FileCacheHandler


    constructor: (@localDb, @replicateDb, @requestCozy) ->
        return instance if instance
        instance = @

        @cache = Object.create(null)
        @localDb ?= app.init.database.localDb
        @replicateDb ?= app.init.database.replicateDb
        @requestCozy ?= app.init.requestCozy

        fs.initialize (err, downloads) =>
            return log.error err if err
            @downloads = downloads


    load: (callback) ->
        log.debug 'load'

        @localDb.query DesignDocuments.FILES_AND_FOLDER_CACHE, (err, results) =>
            if results?.rows
                for cozyFile in results.rows
                    @cache[cozyFile.id] = cozyFile.value
            callback()


    getFileName: (cozyFile) ->
        log.debug 'getFileName'

        return encodeURIComponent cozyFile.name if cozyFile.name

        log.warn JSON.stringify cozyFile
        throw new Error 'cozyFile hasn\'t name field'


    getFolderName: (cozyFile) ->
        return cozyFile._id if cozyFile._id

        log.warn JSON.stringify cozyFile
        throw new Error 'cozyFile hasn\'t _id field'


    isCached: (cozyFile) ->
        @cache[@getFolderName cozyFile]?


    isSameBinary: (cozyFile) ->
        log.debug 'isSameBinary'

        @cache[@getFolderName cozyFile]?.downloaded is \
                cozyFile.binary?.file?.rev


    isDownloaded: (cozyFile) ->
        log.debug 'isDownloaded'

        cacheFile = @cache[@getFolderName cozyFile]
        cacheFile isnt undefined and cacheFile.downloaded isnt false


    isSameName: (cozyFile) ->
        log.debug 'isSameName'

        @cache[@getFolderName cozyFile]?.name is @getFileName cozyFile


    saveInCache: (cozyFile, downloaded, callback) ->
        log.debug 'saveInCache'

        folderName = @getFolderName cozyFile
        fileName = @getFileName cozyFile

        downloadFile =
            _id: folderName
            docType: 'cache'
            fileName: fileName
            binary_id: cozyFile.binary?.file?.id
            binary_rev: cozyFile.binary?.file?.rev
            downloaded: if downloaded then cozyFile.binary?.file?.rev else false

        @cache[folderName] =
            version: downloadFile.binary_rev
            name: fileName
            downloaded: downloadFile.downloaded

        @localDb.get folderName, (err, doc) =>
            unless err
                # this cozyFile exist on cache
                downloadFile._rev = doc._rev
                unless downloaded
                    downloadFile.downloaded = doc.downloaded
                    @cache[folderName].downloaded = doc.downloaded

            @localDb.put downloadFile, callback


    downloadUnsynchronizedFiles: (callback) ->
        log.debug 'downloadUnsynchronizedFiles'

        progressback = ->
        async.forEachOfSeries @cache, (cacheFile, id, cb) =>
            return cb() if cacheFile.downloaded is cacheFile.version
            @replicateDb.get id, (err, cozyFile) =>
                return cb err if err
                @downloadBinary cozyFile, progressback, cb
        , callback


    removeInCache: (cozyFile, callback) ->
        log.debug 'removeInCache'

        folderName = @getFolderName cozyFile
        delete @cache[folderName]

        @localDb.get folderName, (err, doc) =>
            return callback() if err and err.status is 404
            return callback err if err
            @localDb.remove doc, callback


    getBinaryUrl: (cozyFile, callback) ->
        folderName = @getFolderName cozyFile
        fs.getOrCreateSubFolder @downloads, folderName, (err, binaryFolder) =>
            if err and err.code isnt FileError.PATH_EXISTS_ERR
                return callback err
            fileName = @getFileName cozyFile
            if device.platform is "Android"
                fileName = decodeURIComponent fileName
            fs.getFile binaryFolder, fileName, (err, entry) ->
                # file already exist
                return callback null, entry.toURL() if entry
                return callback err


    # Get or download the binary of the specified file in cache.
    # @param cozyFile cozy File document
    # @param progressback progress callback.
    getBinary: (cozyFile, progressback, callback) ->
        log.debug 'getBinary'

        getUrl = =>
            @getBinaryUrl cozyFile, (err, url) =>
                return callback null, url if url
                @cache[@getFolderName cozyFile].downloaded = false
                @getBinary cozyFile, progressback, callback

        return getUrl() if @isSameBinary cozyFile

        @downloadBinary cozyFile, progressback, (err, url) =>
            return callback null, url if url
            return getUrl() if @isDownloaded cozyFile

            callback err


    # Download the binary of the specified file in cache.
    # @param cozyFile cozy File document
    # @param progressback progress callback.
    downloadBinary: (cozyFile, progressback, callback) ->
        log.debug 'downloadBinary'

        folderName = @getFolderName cozyFile
        fs.getOrCreateSubFolder @downloads, folderName, (err, binaryFolder) =>
            if err and err.code isnt FileError.PATH_EXISTS_ERR
                return callback err

            fileName = @getFileName cozyFile
            path = "/data/#{cozyFile._id}/binaries/file"
            androidPath = binaryFolder.toURL() + fileName
            options = @requestCozy.getDataSystemOption path, true
            options.path = androidPath + '_download'
            fs.download options, progressback, (err, entry) =>
                if entry
                    fs.moveTo entry, binaryFolder, fileName, (err, entry) =>
                        return callback err if err
                        log.info "Binary #{fileName} is downloaded."
                        @saveInCache cozyFile, true, (err) ->
                            log.error err if err

                            callback null, entry.toURL()
                else
                    callback err


    getBinaryDirectory: (folderName, callback) ->
        log.debug "getBinaryDirectory"

        fs.getOrCreateSubFolder @downloads, folderName, callback



    # Remove from cache specified file.
    # @param file a cozy file document.
    removeLocal: (cozyFile, callback) ->
        log.info "remove #{cozyFile.name} from cache."

        folderName = @getFolderName cozyFile
        fs.getDirectory @downloads, folderName, (err, binaryFolder) =>
            # code 1: is NOT_FOUND_ERR
            return callback err if err and err.code is not 1
            @removeInCache cozyFile, (err) ->
                return callback err if err
                return callback() unless binaryFolder
                fs.rmrf binaryFolder, (err) ->
                    return callback err if err and err.code is not 1
                    callback()


    open: (url) ->
        success = (entry) ->
            entry.file (file) ->
                fileName = entry.toURL()
                if device.platform is "Android"
                    fileName = decodeURIComponent fileName
                cordova.plugins.fileOpener2.open fileName, file.type,
                    success: -> , # do nothing
                    error: (err) ->
                        log.error err
                        navigator.notification.alert t err.message
        error = (err) ->
            log.error err
        resolveLocalFileSystemURL url, success, error
