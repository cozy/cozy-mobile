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
     *
     * @param {ReplicatorConfig} config - it's replication config.
    ###
    constructor: (@config) ->
        fs.initialize (err, directoryEntry, cache) =>
            @directoryEntry = directoryEntry
            @cache = cache


    ###*
     * When replication change a file.
     *
     * @param {Object} doc - it's a pouchdb file document.
    ###
    change: (doc) ->
        log.info "change"

        @rename doc

    ###*
     * To delete a file.
     *
     * @param {Object} doc - it's a pouchdb file document.
    ###
    delete: (doc) ->
        log.info "delete"

        # delete local file:
        # - get file directory
        # - delete this directory
        fs.getDirectory @directoryEntry, @_fileToEntryName(doc), (err, dir) =>
            return if err and err.code and err.code is 1 # file isn't present
            return log.error err if err
            log.info "delete binary of #{doc.name}"
            fs.rmrf dir, (err) =>
                return log.error err if err
                @_removeFromCacheList @_fileToEntryName doc

    ###*
     * To rename a file.
     *
     * @param {Object} doc - it's a pouchdb file document.
    ###
    rename: (doc) ->
        log.info "rename"

        entry = @_getCacheEntry doc

        # the binary isn't downloaded
        return null unless entry

        fs.getChildren entry, (err, children) =>
            return log.error err if err

            fileName = encodeURIComponent doc.name
            if children.length is 0
                # it's anomaly but download it !
                log.warn "Missing file #{doc.name} on device, fetching it."
                @download doc
            else if children[0].name isnt fileName
                log.info "rename binary of #{doc.name}"
                fs.moveTo children[0], entry, fileName, (err, res)->
                    log.error err if err

    ###*
     * To download a file.
     *
     * @param {Object} doc - it's a pouchdb file document.
    ###
    download: (doc, forced = false) ->
        log.info "download"

        # Don't update the binary if "no wifi"
        DeviceStatus.checkReadyForSync (err, ready, msg) =>
            log.error err if err

            if ready or forced
                name = @_fileToEntryName doc
                fs.getOrCreateSubFolder @downloads, name, (err, directory) =>
                    if err and err.code isnt FileError.PATH_EXISTS_ERR
                        return log.error err

                    unless doc.name
                        err = new Error "no doc name: #{JSON.stringify doc}"
                        return log.error err
                    fileName = encodeURIComponent doc.name

                    fs.getFile directory, fileName, (err, entry) =>

                        # file already exist
                        return null if entry

                        # getFile failed, let's download
                        url = "/data/#{doc._id}/binaries/file"
                        options = @config.makeDSUrl url
                        options.path = directory.toURL() + fileName
                        log.info "download binary of #{doc.name}"
                        fs.download options, null, (err, entry) =>
                            if err
                                # failed to download
                                log.error err
                                fs.delete directory, (err) ->
                                    log.error err
                            else
                                @cache.push directory
                                @_removeAllLocal doc, ->
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
