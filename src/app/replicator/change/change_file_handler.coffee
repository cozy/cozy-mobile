DeletedDocument = require '../../lib/deleted_document'
DeviceStatus = require '../../lib/device_status'
FileCacheHandler = require '../../lib/file_cache_handler'
fs = require '../filesystem'
log = require('../../lib/persistent_log')
    prefix: "ChangeFileHandler"
    date: true
instance = null


###*
 * ChangeFileHandler allows to download, rename and delete a file.
 *
 * @class ChangeFileHandler
###
module.exports = class ChangeFileHandler


    ###*
     * Create a ChangeFileHandler.
    ###
    constructor: ->
        return instance if instance
        instance = @

        _.extend @, Backbone.Events
        @deletedDocument = new DeletedDocument()
        @fileCacheHandler = new FileCacheHandler()
        @directoryEntry = app.init.replicator.downloads


    ###*
     * When replication change a file.
     *
     * @param {Object} doc - it's a pouchdb file document.
    ###
    dispatch: (doc, callback) ->
        log.debug "dispatch"

        cb = (err, doc) =>
            @trigger "change:path", @, doc.path if doc?.path or doc?.path is ""
            callback err

        if doc._deleted
            @_delete doc, (err) =>
                return callback err if err
                @deletedDocument.getDocBeforeDeleted doc._id, cb
        else
            return cb null, doc unless @fileCacheHandler.isCached doc

            if not @fileCacheHandler.isSameBinary doc
                @_download doc, (err) ->
                    cb err, doc
            else if not @fileCacheHandler.isSameName doc
                @_rename doc, (err) ->
                    cb err, doc
            else
                cb null, doc


    ###*
     * To delete a file.
     *
     * @param {Object} doc - it's a pouchdb file document.
    ###
    _delete: (doc, callback) ->
        log.debug "_delete"

        # delete local file:
        # - get file directory
        # - delete this directory
        folderName = @fileCacheHandler.getFolderName doc
        fs.getDirectory @directoryEntry, folderName, (err, dir) =>
            # file isn't present, everything allright
            return callback() if err and err.code and err.code is 1

            return callback err if err # other errors
            log.info "delete binary of #{doc.name}"
            fs.rmrf dir, (err) =>
                return callback err if err
                @fileCacheHandler.removeInCache doc, callback


    ###*
     * To rename a file.
     *
     * @param {Object} doc - it's a pouchdb file document.
    ###
    _rename: (doc, callback) ->
        log.debug "_rename"

        folderName = @fileCacheHandler.getFolderName doc
        @fileCacheHandler.getBinaryDirectory folderName, (err, binaryFolder) =>
            return callback err if err
            fs.getChildren binaryFolder, (err, children) =>
                return callback err if err

                fileName = decodeURIComponent @fileCacheHandler.getFileName doc
                if children.length is 0
                    # it's anomaly but download it !
                    log.warn "Missing file #{fileName} on device, fetching it."
                    @_download doc, callback
                else if children[0].name isnt fileName
                    log.info "rename binary of #{doc.name}"
                    fs.moveTo children[0], binaryFolder, fileName, (err) =>
                        return callback err if err
                        @fileCacheHandler.saveInCache doc, false, callback
                else
                    # Nothing to do
                    callback()


    ###*
     * To download a file.
     *
     * @param {Object} doc - it's a pouchdb file document.
    ###
    _download: (doc, callback) ->
        log.debug "_download"

        # Don't update the binary if "no wifi"
        DeviceStatus.checkReadyForSync (err, ready, msg) =>
            return callback err if err

            if ready
                progressback = ->
                @fileCacheHandler.getBinary doc, progressback, callback
            else
                @fileCacheHandler.saveInCache doc, false, callback
