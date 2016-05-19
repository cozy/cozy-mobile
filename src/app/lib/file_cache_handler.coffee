async = require 'async'
DesignDocuments = require '../replicator/design_documents'
fs = require '../replicator/filesystem'
log = require('./persistent_log')
    prefix: "FileCacheHandler"
    date: true


instance = null


module.exports = class FileCacheHandler


    constructor: (@db, @requestCozy) ->
        return instance if instance
        instance = @
        @cache = []
        @db ?= app.init.database.localDb
        @requestCozy ?= app.init.requestCozy
        @load ->
        fs.initialize (err, downloads) =>
            return log.error err if err
            @downloads = downloads


    load: (callback) ->
        log.debug 'load'

        @db.query DesignDocuments.FILES_AND_FOLDER_CACHE, (err, results) =>
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
        log.debug 'getFolderName'

        return cozyFile._id if cozyFile._id

        log.warn JSON.stringify cozyFile
        throw new Error 'cozyFile hasn\'t _id field'


    isCached: (cozyFile) ->
        log.debug 'isCached'

        @cache[@getFolderName cozyFile]?


    isSameBinary: (cozyFile) ->
        log.debug 'isSameBinary'

        @cache[@getFolderName cozyFile]?.version is cozyFile.binary?.file?.rev


    isSameName: (cozyFile) ->
        log.debug 'isSameName'

        @cache[@getFolderName cozyFile]?.name is @getFileName cozyFile


    saveInCache: (cozyFile, callback) ->
        log.debug 'saveInCache'

        folderName = @getFolderName cozyFile
        fileName = @getFileName cozyFile

        downloadFile =
            _id: folderName
            docType: 'cache'
            fileName: fileName
            binary_id: cozyFile.binary?.file?.id
            binary_rev: cozyFile.binary?.file?.rev

        @cache[folderName] =
            version: downloadFile.binary_rev
            name: fileName

        @db.get folderName, (err, doc) =>
            downloadFile._rev = doc._rev unless err

            @db.put downloadFile, callback


    removeInCache: (cozyFile, callback) ->
        log.debug 'removeInCache'

        folderName = @getFolderName cozyFile
        delete @cache[folderName]

        @db.get folderName, (err, doc) =>
            return callback() if err and err.status is 404
            return callback err if err
            @db.remove doc, callback


    # Download the binary of the specified file in cache.
    # @param cozyFile cozy File document
    # @param progressback progress callback.
    # TODO: refactoring name to downloadBinary
    getBinary: (cozyFile, progressback, callback) ->
        log.debug "getBinary"

        folderName = @getFolderName cozyFile
        return callback folderName unless typeof folderName is 'string'
        fileName = @getFileName cozyFile
        return callback fileName unless typeof fileName is 'string'

        fs.getOrCreateSubFolder @downloads, folderName, (err, binaryFolder) =>
            if err and err.code? isnt FileError.PATH_EXISTS_ERR
                return callback err
            fs.getFile binaryFolder, fileName, (err, entry) =>
                # file already exist
                if entry and @isSameBinary cozyFile
                    return callback null, entry.toURL()

                # getFile failed, let's download
                path = "/data/#{cozyFile._id}/binaries/file"
                options = @requestCozy.getDataSystemOption path, true
                options.path = binaryFolder.toURL() + fileName
                log.info "download binary of #{fileName}"
                fs.download options, progressback, (err, entry) =>
                    # TODO : Is it reachable code ? http://git.io/v08Ap
                    # TODO changing the message ! ?
                    errMessage = "This file isnt available offline"
                    if err?.message? and err.message is errMessage and \
                            @isCached cozyFile
                        for entry in @cache
                            if entry.name.indexOf(folderName) isnt -1
                                path = entry.toURL() + fileName
                                return callback null, path

                        return callback err
                    else if err
                        # failed to download
                        fs.delete binaryFolder, (delerr) ->
                            log.error delerr if delerr
                            callback err
                    else
                        @saveInCache cozyFile, (err) =>
                            log.error err if err

                            callback null, entry.toURL()
                            @_removeAllLocal cozyFile, ->


    getBinaryDirectory: (folderName, callback) ->
        log.debug "getBinaryDirectory"

        fs.getOrCreateSubFolder @downloads, folderName, callback


    # Remove all versions in saved locally of the specified file-id, except the
    # specified rev.
    _removeAllLocal: (file, callback) ->
        async.eachSeries @cache, (entry, cb) =>
            if entry.name.indexOf(file.binary.file.id) isnt -1 and \
                    entry.name isnt @getFolderName(file)
                fs.getDirectory @downloads, entry.name, (err, binfolder) =>
                    return cb err if err
                    fs.rmrf binfolder, (err) =>
                        log.error err if err
                        @removeInCache entry, cb
            else
                cb()
        , callback



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
