DesignDocuments = require "../replicator/design_documents"
log = require("./persistent_log")
    prefix: "AndroidPictureFolderHandler"
    date: true


module.exports = class AndroidPictureFolderHandler


    ERROR_FOLDER_EXIST: "Pictures folder isn't created."


    constructor: (@deviceName, @db) ->
        @deviceName ?= app.replicator.config.deviceName
        @db ?= app.replicator.db


    getOrCreate: (callback) ->
        log.info "getOrCreate"

        @get (err, folderPictures) =>
            if err?.message is @ERROR_FOLDER_EXIST
                @create callback
            else
                callback err, folderPictures


    get: (callback) ->
        log.info "get"

        options =
            key: [
                ""                               # path
                "1_#{t('photos').toLowerCase()}" # emit in design doc for folder
            ]
            include_docs: true
            limit: 1

        @db.query DesignDocuments.FILES_AND_FOLDER, options, (err, results) =>
            return callback err if err

            if results.rows.length > 0
                picturesFolder = results.rows[0].doc
                callback null, picturesFolder
            else
                callback new Error @ERROR_FOLDER_EXIST


    create: (callback) ->
        log.info "create"

        now = new Date().toISOString()
        picturesFolder =
            docType          : 'Folder'
            name             : t 'photos'
            path             : ''
            lastModification : now
            creationDate     : now
            tags             : ['from-' + @deviceName]

        @db.post picturesFolder, (err, newPicturesFolder) ->
            return callback err if err

            callback null, newPicturesFolder
