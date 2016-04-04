DeviceStatus = require '../../lib/device_status'
fs = require '../filesystem'
log = require('../../lib/persistent_log')
    prefix: "ChangeFileHandler"
    date: true

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
        @directoryEntry = app.init.replicator.downloads
        @cache = app.init.replicator.cache


    ###*
     * When replication change a file.
     *
     * @param {Object} doc - it's a pouchdb file document.
    ###
    dispatch: (doc, callback) ->
        log.debug "dispatch"

        if doc._deleted
            @_delete doc, callback

        else
            entry = @_getCacheEntry doc

            # Entry is false if this file isn't cached.
            return callback() unless entry

            if entry.name isnt @_fileToEntryName doc
                @_update doc, callback

            else
                @_rename doc, entry, callback

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
        fs.getDirectory @directoryEntry, @_fileToEntryName(doc), (err, dir) =>
            # file isn't present, everything allright
            return callback() if err and err.code and err.code is 1

            return callback err if err # other errors
            log.info "delete binary of #{doc.name}"
            fs.rmrf dir, (err) =>
                return callback err if err
                @_removeFromCacheList @_fileToEntryName doc
                callback()

    _update: (doc, callback) ->
        log.debug "_update"

        @_download doc, callback


    ###*
     * To rename a file.
     *
     * @param {Object} doc - it's a pouchdb file document.
    ###
    _rename: (doc, entry, callback) ->
        log.debug "_rename"

        fs.getChildren entry, (err, children) =>
            return callback err if err

            fileName = encodeURIComponent doc.name
            if children.length is 0
                # it's anomaly but download it !
                log.warn "Missing file #{doc.name} on device, fetching it."
                @_download doc, callback
            else if children[0].name isnt fileName
                log.info "rename binary of #{doc.name}"
                fs.moveTo children[0], entry, fileName, callback

            else
                # Nothing to do
                callback()


    ###*
     * TODO: factoryze with main.getBinary in some way.
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
                name = @_fileToEntryName doc
                fs.getOrCreateSubFolder @downloads, name, (err, directory) =>
                    if err and err.code isnt FileError.PATH_EXISTS_ERR
                        return callback err

                    unless doc.name
                        err = new Error "no doc name: #{JSON.stringify doc}"
                        return callback err
                    fileName = encodeURIComponent doc.name

                    fs.getFile directory, fileName, (err, entry) =>

                        # file already exist
                        return callback null, entry.toURL() if entry

                        # getFile failed, let's download
                        requestCozy = window.app.init.requestCozy
                        path = "/data/#{doc._id}/binaries/file"
                        options = requestCozy.getDataSystemOption path
                        options.path = directory.toURL() + fileName
                        log.info "download binary of #{doc.name}"
                        fs.download options, null, (err, entry) =>
                            if err
                                # failed to download
                                log.error err
                                fs.delete directory, callback
                            else
                                @cache.push directory
                                @_removeAllLocal doc, callback
            else
                log.info msg


    ###*
     * To get cache entry file.
     *
     * @param {Object} doc - it's a pouchdb file document.
     *
     * @return {String|false}
    ###
    _getCacheEntry: (doc) ->
        # early created file may not have binary property yet.
        if doc.binary
            entries = @cache.filter (entry) ->
                entry.name.indexOf(doc.binary.file.id) isnt -1
            return entries[0] if entries.length isnt 0
        return false


    ###*
     * Return the conventional name of the in filesystem folder for the
     * specified file.
     *
     * @param {Object} doc - it's a pouchdb file document
     *
     * @return {String} - conventional name of the in filesystem folder.
    ###
    _fileToEntryName: (doc) ->
        return doc.binary.file.id + '-' + doc.binary.file.rev


    ###*
     * Remove specified entry from @cache.
     *
     * @param {String} entryName - an entry name of the @cache to remove.
    ###
    _removeFromCacheList: (entryName) ->
        for currentEntry, index in @cache when currentEntry.name is entryName
            @cache.splice index, 1
            break


    ###*
     * Remove all versions in saved locally of the specified file-id, except the
     * specified rev.
     *
     * @param {Object} doc - it's a pouchdb file document
    ###
    _removeAllLocal: (doc) ->
        async.eachSeries @cache, (entry, cb) =>
            if entry.name.indexOf(doc.binary.file.id) isnt -1 and \
                    entry.name isnt @_fileToEntryName(doc)
                fs.getDirectory @downloads, entry.name, (err, directory) =>
                    return cb err if err
                    fs.rmrf directory, (err) =>
                        log.error err if err
                        @_removeFromCacheList entry.name
                        cb()
            else
                cb()
        , (err, res) ->
            log.error err if err
