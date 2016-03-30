DesignDocuments = require "../replicator/design_documents"
log = require("./persistent_log")
    prefix: "AndroidPictureHandler"
    date: true

androidCalendarsCache = null

module.exports = class AndroidPictureHandler

    ERROR_FOLDER_EXIST: "Pictures folder isn't created."

    constructor: (@imagesBrowser, @db, @localDb) ->
        @imagesBrowser ?= ImagesBrowser
        @db ?= app.replicator.db
        @localDb ?= app.replicator.photosDB

    getAllPath: (callback) ->
        log.info "getAllPath"

        @imagesBrowser.getImagesList (err, picturesPath) ->
            return callback err if err

            # Filter images : keep only the ones from Camera
            picturesPath = picturesPath.filter (picturePath) ->
                picturePath?.indexOf('/DCIM/') isnt -1

            # Filter pathes with ':' (colon), as cordova plugin won't pick them
            # especially ':nopm:' ending files,
            # which may be google+ 's NO Photo Manager
            picturesPath = picturesPath.filter (path) -> path.indexOf(':') is -1

            callback null, picturesPath


    getSynchronizedPicturesInLocal: (callback) ->
        log.info "getSynchronizedPicturesInLocal"

        @localDb.query DesignDocuments.PHOTOS_BY_LOCAL_ID, (err, pictures) ->
            return callback err if err

            pictures = pictures.rows.map (row) -> row.key

            callback null, pictures


    getSynchronizedPicturesInRemote: (callback) ->
        log.info "getSynchronizedPicturesInRemote"

        options =
            startkey: ['/' + t 'photos']
            endkey: ['/' + t('photos'), {}]

        @db.query DesignDocuments.FILES_AND_FOLDER, options, (err, pictures) ->
            return callback err if err

            # We pick up the filename from the key to improve speed :
            # query without include_doc are 100x faster
            pictures = pictures.rows.map (row) -> row.key[1]?.slice 2

            callback null, pictures

    saveInLocal: (path, callback) ->
        log.info "saveInLocal"

        picture =
            docType : 'Photo'
            localId: path

        @localDb.post picture, callback
