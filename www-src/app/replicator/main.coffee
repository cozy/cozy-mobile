async = require 'async'
PouchDB = require 'pouchdb'
semver = require 'semver'
request = require '../lib/request'
fs = require './filesystem'
DesignDocuments = require './design_documents'
ReplicatorConfig = require './replicator_config'
DeviceStatus = require '../lib/device_status'
ChangeDispatcher = require './change/change_dispatcher'

DBNAME = "cozy-files.db"
DBPHOTOS = "cozy-photos.db"


PLATFORM_VERSIONS =
    'proxy': '>=2.1.11'
    'data-system': '>=2.1.8'

log = require('../lib/persistent_log')
    prefix: "replicator"
    date: true

#Replicator extends Model to watch/set inBackup, inSync
module.exports = class Replicator extends Backbone.Model

    db: null
    config: null

    # backup images functions are in replicator_backups
    _.extend Replicator.prototype, require './replicator_backups'

    _.extend Replicator.prototype, require './replicator_migration'

    defaults: ->
        inSync: false
        inBackup: false


    initFileSystem: (callback) ->
        fs.initialize (err, downloads, cache) =>
            return callback err if err
            @downloads = downloads
            @cache = cache
            callback()


    initDB: (callback) ->
        # Migrate to idb
        dbOptions = adapter: 'idb', cache: false
        new PouchDB DBNAME, dbOptions, (err, db) =>
            if err
                #keep sqlite db, no migration.
                dbOptions = adapter: 'websql'
                @db = new PouchDB DBNAME, dbOptions
                @photosDB = new PouchDB DBPHOTOS, dbOptions
                return @migrateConfig callback

            @db = db
            @photosDB = new PouchDB DBPHOTOS, dbOptions
            @migrateDBs callback


    initConfig: (callback) ->
        @config = new ReplicatorConfig @db
        @config.fetch callback


    upsertLocalDesignDocuments: (callback) ->
        designDocs = new DesignDocuments @db, @photosDB
        designDocs.createOrUpdateAllDesign callback

    checkPlatformVersions: (callback) ->
        request.get
            url: "#{@config.getScheme()}://#{@config.get('cozyURL')}/versions"
            auth: @config.get 'auth'
            json: true
        , (err, response, body) ->
            return callback err if err # TODO i18n ?

            for item in body
                [s, app, version] = item.match /([^:]+): ([\d\.]+)/
                if app of PLATFORM_VERSIONS
                    unless semver.satisfies(version, PLATFORM_VERSIONS[app])
                        msg = t 'error need min %version for %app'
                        msg = msg.replace '%app', app
                        msg = msg.replace '%version', PLATFORM_VERSIONS[app]
                        return callback new Error msg

            # Everything fine
            callback()


    destroyDB: (callback) ->
        @db.destroy (err) =>
            return callback err if err
            @photosDB.destroy (err) =>
                return callback err if err
                fs.rmrf @downloads, callback


    # pings the cozy to check the credentials without creating a device
    checkCredentials: (config, callback) ->
        url = "#{@config.getScheme()}://#{config.cozyURL}"
        request.post
            uri: "#{url}/login"
            json:
                username: 'owner'
                password: config.password
        , (err, response, body) ->
            if err and config.cozyURL.indexOf('@') isnt -1
                error = t 'bad credentials, did you enter an email address'
            else if err and err.message is "Unexpected token <"
                error = t err.message
            else if err
                # Unexpected error, just show it to the user.
                log.error err
                error = err.message
                if error.indexOf('CORS request rejected') isnt -1
                    error = t 'connexion error'
            else if response?.status is 0
                error = t 'connexion error'
            else if response?.statusCode isnt 200
                error = err?.message or body.error or body.message
            else
                error = null

            callback error

    permissions:
        File: description: "files permission description"
        Folder: description: "folder permission description"
        Binary: description: "binary permission description"
        Contact: description: "contact permission description"
        Event: description: "event permission description"
        Notification: description: "notification permission description"
        Tag: description: "tag permission description"


    registerRemote: (newConfig, callback) ->
        request.post
            uri: "#{@config.getScheme()}://#{newConfig.cozyURL}/device"
            auth:
                username: 'owner'
                password: newConfig.password
            json:
                login: newConfig.deviceName
                permissions: @permissions

        , (err, response, body) =>
            if err
                callback err
            else if response.statusCode is 401 and response.reason
                callback new Error 'cozy need patch'
            else if response.statusCode is 401
                callback new Error 'wrong password'
            else if response.statusCode is 400
                callback new Error 'device name already exist'
            else if response.statusCode isnt 201
                log.error "while registering device:  #{response.statusCode}"
                callback new Error response.statusCode, response.reason
            else
                _.extend newConfig,
                    devicePassword: body.password
                    deviceName: body.login
                    devicePermissions:
                        @config.serializePermissions body.permissions
                    auth:
                        username: body.login
                        password: body.password

                @config.save newConfig, callback


    updatePermissions: (password, callback) ->
        request.put
            uri: "#{@config.getCozyUrl()}/device/#{@config.get('deviceName')}"
            auth:
                username: 'owner'
                password: password
            json:
                login: @config.get 'deviceName'
                permissions: @permissions
        , (err, response, body) =>
            return callback err if err
            log.debug body

            @config.save
                devicePassword: body.password
                deviceName: body.login
                devicePermissions: @config.serializePermissions body.permissions
                auth:
                    username: body.login
                    password: body.password
            , callback

    putFilters: (callback) ->
        log.info "setReplicationFilter"
        @config.getFilterManager().setFilter callback


    putRequests: (callback) ->
        requests = require './remote_requests'

        reqList = []
        for docType, reqs of requests
            for reqName, body of reqs
                reqList.push
                    type: docType
                    name: reqName
                    # Copy/Past from cozydb, to avoid view multiplication
                    # TODO: reduce is not supported yet
                    body: map: """
                function (doc) {
                  if (doc.docType.toLowerCase() === "#{docType}") {
                    filter = #{body.toString()};
                    filter(doc);
                  }
                }
            """

        async.eachSeries reqList, (req, cb) =>
            options = @config.makeDSUrl "/request/#{req.type}/#{req.name}/"
            options.body = req.body
            request.put options, cb
        , callback

    takeCheckpoint: (callback) ->
        url = '/_changes?descending=true&limit=1'
        options = @config.makeReplicationUrl url
        request.get options, (err, res, body) =>
            return callback err if err
            @config.save checkpointed: body.last_seq, callback


    # Fetch all documents, with a previously put couchdb view.
    _fetchAll: (options, callback) ->
        requestOptions = @config.makeDSUrl "/request/#{options.docType}/all/"
        requestOptions.body = include_docs: true, show_revs: true

        request.post requestOptions, (err, res, rows) ->
            if not err and res.statusCode isnt 200
                err = new Error res.statusCode, res.reason

            return callback err if err
            callback null, rows


    # 1. Fetch all documents of specified docType
    # 2. Put in PouchDB
    # 2.1 : optionnaly, fetch attachments before putting in pouchDB
    # Return the list of added doc to PouchDB.
    copyView: (options, callback) ->
        log.info "enter copyView for #{options.docType}."
        # Last step
        putInPouch = (doc, cb) =>
            @db.put doc, 'new_edits':false, (err) ->
                return cb err if err
                cb null, doc

        # 1. Fetch all documents
        retryOptions =
            times: options.retry or 1
            interval: 20 * 1000

        async.retry retryOptions, ((cb) => @_fetchAll options, cb)
        , (err, rows) =>
            return callback null unless rows?.length isnt 0

            # 2. Put in PouchDB
            async.mapSeries rows, (row, cb) =>
                doc = row.doc

                # 2.1 Fetch attachment if needed (typically contact docType)
                if options.attachments is true and doc._attachments?
                # TODO? needed : .picture?
                    request.get @config.makeReplicationUrl( \
                    "/#{doc._id}?attachments=true"), (err, res, body) ->
                        # Continue on error (we just miss the avatar in case
                        # of contacts)
                        unless err
                            doc = body

                        putInPouch doc, cb

                else # No attachments
                    putInPouch doc, cb

            , callback


    # update index for further speeds up.
    updateIndex: (callback) ->
        # build pouch's map indexes
        @db.query DesignDocuments.FILES_AND_FOLDER, {}, =>
            # build pouch's map indexes
            @db.query DesignDocuments.LOCAL_PATH, {}, -> callback()

# END initialisations methods

# BEGIN Cache methods

    # Return the conventionnal name of the in filesystem folder for the
    # specified file.
    # @param file a cozy file document.
    _fileToEntryName: (file) ->
        return file.binary.file.id + '-' + file.binary.file.rev

    # Check if any version of the file is present in cache.
    # @param file a cozy file document.
    # @return true if any version of the file is present
    fileInFileSystem: (file) =>
        if file.docType.toLowerCase() is 'file'
            return @cache.some (entry) ->
                entry.name.indexOf(file.binary.file.id) isnt -1

    # Check if the file, with the specified version, is present in file system
    # @param file a cozy file document.
    # @return true if the file with the expected version is present
    fileVersion: (file) =>
        if file.docType.toLowerCase() is 'file'
            @cache.some (entry) =>
                entry.name is @_fileToEntryName file

    # Check if the all the subtree of the specified path is in cache.
    # @param path the path to the subtree to check
    # @param callback get true as result if the whole subtree is present.
    folderInFileSystem: (path, callback) =>
        options =
            startkey: path
            endkey: path + '\uffff'

        fsCacheFolder = @cache.map (entry) -> entry.name

        @db.query DesignDocuments.PATH_TO_BINARY, options, (err, results) ->
            return callback err if err
            return callback null, null if results.rows.length is 0
            callback null, _.every results.rows, (row) ->
                row.value in fsCacheFolder


    # Remove specified entry from @cache.
    # @param entry an entry of the @cache to remove.
    _removeFromCacheList: (entryName) ->
        for currentEntry, index in @cache when currentEntry.name is entryName
            @cache.splice index, 1
            break



    # Download the binary of the specified file in cache.
    # @param model cozy File document
    # @param progressback progress callback.
    getBinary: (model, progressback, callback) ->
        fs.getOrCreateSubFolder @downloads, @_fileToEntryName(model)
        , (err, binfolder) =>
            if err and err.code isnt FileError.PATH_EXISTS_ERR
                return callback err
            unless model.name
                return callback new Error 'no model name :' +
                        JSON.stringify(model)
            fileName = encodeURIComponent model.name
            fs.getFile binfolder, fileName, (err, entry) =>
                return callback null, entry.toURL() if entry

                # getFile failed, let's download
                options = @config.makeDSUrl "/data/#{model._id}/binaries/file"
                options.path = binfolder.toURL() + fileName
                log.info "download binary of #{model.name}"
                fs.download options, progressback, (err, entry) =>
                    # TODO : Is it reachable code ? http://git.io/v08Ap
                    # TODO changing the message ! ?
                    if err?.message? and
                    err.message is "This file isnt available offline" and
                    @fileInFileSystem model
                        for entry in cache
                            if entry.name.indexOf(binary_id) isnt -1
                                path = entry.toURL() + fileName
                                return callback null

                        return callback err
                    else if err
                        # failed to download
                        fs.delete binfolder, (delerr) ->
                            #@TODO handle delerr
                            callback err
                    else
                        @cache.push binfolder
                        callback null, entry.toURL()
                        @_removeAllLocal model, ->


    # Remove all versions in saved locally of the specified file-id, except the
    # specified rev.
    _removeAllLocal: (file, callback) ->
        async.eachSeries @cache, (entry, cb) =>
            if entry.name.indexOf(file.binary.file.id) isnt -1 and \
                    entry.name isnt @_fileToEntryName(file)
                fs.getDirectory @downloads, entry.name, (err, binfolder) =>
                    return cb err if err
                    fs.rmrf binfolder, (err) =>
                        @_removeFromCacheList entry.name
                        cb()
            else
                cb()
        , callback


    # Download recursively all files in the specified folder.
    # @param folder cozy folder document of the subtree's root
    # @param progressback progress callback
    getBinaryFolder: (folder, progressback, callback) ->
        @_getDbFilesOfFolder folder, (err, files) =>
            return callback err if err

            totalSize = files.reduce ((sum, file) -> sum + file.size), 0

            fs.freeSpace (err, available) =>
                return callback err if err
                if totalSize > available * 1024 # available is in KB
                    log.warn 'not enough space'
                    alert t 'not enough space'
                    callback null

                else
                    progressHandlers = {}
                    reportProgress = (id, done, total) ->
                        progressHandlers[id] = [done, total]
                        total = done = 0
                        for key, status of progressHandlers
                            done += status[0]
                            total += status[1]
                        progressback done, total

                    async.eachLimit files, 5, (file, cb) =>
                        pb = reportProgress.bind null, file._id
                        @getBinary file, pb, cb
                    , callback


    # Find all files in (recursively) the specified folder.
    # @param folder cozy folder document of the subtree's root
    _getDbFilesOfFolder: (folder, callback) ->
        path = folder.path
        path += '/' + folder.name
        options =
            startkey: [path]
            endkey: [path + '/\uffff', {}]
            include_docs: true

        @db.query DesignDocuments.FILES_AND_FOLDER, options, (err, results) ->
            return callback err if err
            docs = results.rows.map (row) -> row.doc
            files = docs.filter (doc) -> doc.docType?.toLowerCase() is 'file'

            callback null, files


    # Remove from cache specified file.
    # @param file a cozy file document.
    removeLocal: (file, callback) ->
        log.info "remove #{file.name} from cache."

        fs.getDirectory @downloads, @_fileToEntryName(file), (err, binfolder) =>
            return callback err if err
            fs.rmrf binfolder, (err) =>
                @_removeFromCacheList @_fileToEntryName(file)
                callback err


    removeLocalFolder: (folder, callback) ->
        @_getDbFilesOfFolder folder, (err, files) =>
            return callback err if err

            async.eachSeries files, (file, cb) =>
                @removeLocal file, cb
            , callback


    # wrapper around _sync to maintain the state of inSync
    sync: (options, callback) ->
        return callback null if @get 'inSync'

        log.info "start a sync"
        @set 'inSync', true
        @_sync options, (err) =>
            @set 'inSync', false
            callback err


    # One-shot replication
    # Called for :
    #    * first replication
    #    * replication at each start
    #    * replication force by user
    _sync: (options, callback) ->
        log.info "_sync"
        options.live = false

        @stopRealtime()

        ReplicationLauncher = require "./replication_launcher"
        @replicationLauncher = new ReplicationLauncher @config, app.router
        @replicationLauncher.start options, =>
            # clean @replicationLauncher when sync finished
            @stopRealtime()
            callback.apply @, arguments

    ###*
     * Start real time replication
    ###
    startRealtime: =>
        log.info "startRealtime"

        @stopRealtime() if @replicationLauncher

        ReplicationLauncher = require "./replication_launcher"
        @replicationLauncher = new ReplicationLauncher @config, app.router
        @replicationLauncher.start live: true

    # Stop replication.
    stopRealtime: =>
        @replicationLauncher?.stop()
        delete @replicationLauncher

    # Update cache files with outdated revisions. Called while backup<
    syncCache:  (callback) ->
        @set 'backup_step', 'files_sync'
        @set 'backup_step_done', null

        # TODO: Add optimizations on db.query : avoid include_docs on big list.
        options =
            keys: @cache.map (entry) -> return entry.name.split('-')[0]
            include_docs: true

        @db.query DesignDocuments.BY_BINARY_ID, options, (err, results) =>
            return callback err if err

            changeDispatcher = new ChangeDispatcher @config
            processed = 0
            @set 'backup_step', 'files_sync'
            @set 'backup_step_total', results.rows.length
            async.eachSeries results.rows, (row, cb) =>
                @set 'backup_step_done', processed++
                changeDispatcher.dispatch row.doc, cb
            , callback

