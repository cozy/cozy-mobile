async = require 'async'
PouchDB = require 'pouchdb'
request = require '../lib/request'
fs = require './filesystem'
DesignDocuments = require './design_documents'
ReplicatorConfig = require './replicator_config'
DeviceStatus = require '../lib/device_status'
DBNAME = "cozy-files.db"
DBPHOTOS = "cozy-photos.db"

PLATFORM_MIN_VERSIONS =
    'proxy': '2.1.11'
    'data-system': '2.1.6'

log = require('../lib/persistent_log')
    prefix: "replicator"
    date: true

#Replicator extends Model to watch/set inBackup, inSync
module.exports = class Replicator extends Backbone.Model

    db: null
    config: null

    # backup images functions are in replicator_backups
    _.extend Replicator.prototype, require './replicator_backups'
    # Contact sync functions are in replicator_contacts
    _.extend Replicator.prototype, require './replicator_contacts'
    _.extend Replicator.prototype, require './replicator_calendars'

    _.extend Replicator.prototype, require './replicator_migration'

    defaults: ->
        inSync: false
        inBackup: false


    initDB: (callback) ->
        # Migrate to idb
        dbOptions = adapter: 'idb'
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


    init: (callback) ->
        fs.initialize (err, downloads, cache) =>
            return callback err if err
            @downloads = downloads
            @cache = cache
            @initDB (err) =>
                return callback err if err
                designDocs = new DesignDocuments @db, @photosDB
                designDocs.createOrUpdateAllDesign (err) =>
                    return callback err if err
                    @config = new ReplicatorConfig(this)
                    @config.fetch callback


    checkPlatformVersions: (callback) ->
        # TODO use lib/compare_version
        cutVersion = (s) ->
            parts = s.match /(\d+)\.(\d+)\.(\d+)/
            # Keep only useful data (first elem is full string)
            parts = parts.slice 1, 4
            parts = parts.map (s) -> parseInt s
            return major: parts[0], minor: parts[1], patch: parts[2]

        request.get
            url: "#{@config.getScheme()}://#{@config.get('cozyURL')}/versions"
            auth: @config.get 'auth'
            json: true
        , (err, response, body) ->
            return callback err if err # TODO i18n ?

            for item in body
                [s, app, version] = item.match /([^:]+): ([\d\.]+)/
                if app of PLATFORM_MIN_VERSIONS
                    minVersion = cutVersion PLATFORM_MIN_VERSIONS[app]
                    version = cutVersion version
                    if version.major < minVersion.major or
                    version.minor < minVersion.minor or
                    version.patch < minVersion.patch
                        msg = t 'error need min %version for %app'
                        msg = msg.replace '%app', app
                        msg = msg.replace '%version', PLATFORM_MIN_VERSIONS[app]
                        return callback new Error msg

            # Everything fine
            callback()

    # Get locale from cozy, update in (saved) config, and in app if changed
    updateLocaleFromCozy: (callback) ->
        options = @config.makeDSUrl "/request/cozyinstance/all/"
        options.body = include_docs: true

        request.post options, (err, res, models) =>
            return callback err if err
            return callback new Error 'No CozyInstance' if models.length <= 0

            instance = models[0].doc
            if instance.locale and instance.locale isnt @config.get('locale')
                # Update
                app.translation.setLocale value: instance.locale
                @config.save locale: instance.locale, callback
            else
                callback()


    destroyDB: (callback) ->
        @db.destroy (err) =>
            return callback err if err
            @photosDB.destroy (err) =>
                return callback err if err
                fs.rmrf @downloads, callback



    # pings the cozy to check the credentials without creating a device
    checkCredentials: (config, callback) ->
        request.post
            uri: "#{@config.getScheme()}://#{config.cozyURL}/login"
            json:
                username: 'owner'
                password: config.password
        , (err, response, body) ->
            if err
                if config.cozyURL.indexOf('@') isnt -1
                    error = t 'bad credentials, did you enter an email address'
                else
                    # Unexpected error, just show it to the user.
                    log.error err
                    return callback err.message

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
        CozyInstance: description: "cozyinstance permission description"


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


    # Fetch current state of replicated views. Avoid pouchDB bug with heavy
    # change list.
    initialReplication: (callback) ->
        @set 'initialReplicationStep', 0

        DeviceStatus.checkReadyForSync (err, ready, msg) =>
            return callback err if err
            unless ready
                return callback new Error msg

            log.info "enter initialReplication"

            # initialReplication may be called to re-sync data...
            @stopRealtime()

            last_seq = 0

            async.series [
                (cb) => @putRequests cb
                # we store last_seq before copying files & folder
                # to avoid losing changes occuring during replication
                (cb) =>
                    url = '/_changes?descending=true&limit=1'
                    options = @config.makeReplicationUrl url
                    request.get options, (err, res, body) ->
                        return cb err if err
                        last_seq = body.last_seq
                        cb()

                # Force checkpoint to 0
                (cb) => @copyView 'file', cb
                (cb) => @set('initialReplicationStep', 1) and cb null
                (cb) => @copyView 'folder', cb

                (cb) => @set('initialReplicationStep', 2) and cb null
                # TODO: it copies all notifications (persistent ones too).
                (cb) =>
                    if @config.get 'cozyNotifications'
                        @copyView 'notification', cb

                    else cb()

                (cb) => @set('initialReplicationStep', 3) and cb null
                (cb) => @initContactsInPhone last_seq, cb
                (cb) => @set('initialReplicationStep', 4) and cb null
                (cb) => @initEventsInPhone last_seq, cb

                (cb) => @set('initialReplicationStep', 5) and cb null
                # Save last sequences
                (cb) => @config.save checkpointed: last_seq, cb
                # build the initial state of FilesAndFolder view index
                (cb) => @db.query DesignDocuments.FILES_AND_FOLDER, {}, cb

            ], (err) =>
                log.info "end of inital replication"
                @set 'initialReplicationStep', 5
                callback err
                # updateIndex In background
                @updateIndex -> log.info "Index built"

    copyView: (model, callback) ->
        options =
            times: 5
            interval: 20 * 1000

        async.retry options, ((cb) => @_copyView model, cb), callback

    _copyView: (model, callback) ->
        log.info "enter copyView for #{model}."

        options = @config.makeDSUrl "/request/#{model}/all/"
        options.body = include_docs: true, show_revs: true

        request.post options, (err, res, models) =>
            if err or res.statusCode isnt 200
                unless err?
                    err = new Error res.statusCode, res.reason
                return callback err

            return callback null unless models?.length isnt 0
            async.eachSeries models, (doc, cb) =>
                model = doc.doc
                @db.put model, 'new_edits':false, cb()
            , callback


    # update index for further speeds up.
    updateIndex: (callback) ->
        # build the search index
        @db.search
            build: true
            fields: ['name']
        , (err) =>
            log.info "INDEX BUILT"
            log.warn err if err
            # build pouch's map indexes
            @db.query DesignDocuments.FILES_AND_FOLDER, {}, =>
                # build pouch's map indexes
                @db.query DesignDocuments.LOCAL_PATH, {}, ->
                    callback null

# END initialisations methods

# BEGIN Cache methods

    # Return the conventionnal name of the in filesystem folder for the
    # specified file.
    # @param file a cozy file document.
    fileToEntryName: (file) ->
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
                entry.name is @fileToEntryName file

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
    removeFromCacheList: (entryName) ->
        for currentEntry, index in @cache when currentEntry.name is entryName
            @cache.splice index, 1
            break



    # Download the binary of the specified file in cache.
    # @param model cozy File document
    # @param progressback progress callback.
    getBinary: (model, progressback, callback) ->
        fs.getOrCreateSubFolder @downloads, @fileToEntryName(model)
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
                        @removeAllLocal model, ->


    # Remove all versions in saved locally of the specified file-id, except the
    # specified rev.
    removeAllLocal: (file, callback) ->
        async.eachSeries @cache, (entry, cb) =>
            if entry.name.indexOf(file.binary.file.id) isnt -1 and \
                    entry.name isnt @fileToEntryName(file)
                fs.getDirectory @downloads, entry.name, (err, binfolder) =>
                    return cb err if err
                    fs.rmrf binfolder, (err) =>
                        @removeFromCacheList entry.name
                        cb()
            else
                cb()
        , callback


    # Download recursively all files in the specified folder.
    # @param folder cozy folder document of the subtree's root
    # @param progressback progress callback
    getBinaryFolder: (folder, progressback, callback) ->
        @getDbFilesOfFolder folder, (err, files) =>
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
    getDbFilesOfFolder: (folder, callback) ->
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


    # Update the local copy  (options.entry) of the file (options.file)
    # @param options object with entry and file (cozy doc)
    updateLocal: (options, callback) =>
        file = options.file
        entry = options.entry

        fileName = encodeURIComponent file.name
        noop = ->

        if file._deleted
            @removeLocal file, callback

        # check binary revs
        else if entry.name isnt @fileToEntryName(file)
            # Don't update the binary if "no wifi"
            DeviceStatus.checkReadyForSync (err, ready, msg) =>
                return callback err if err

                if ready
                    # Download the new version.
                    @getBinary file, noop, callback
                else
                    callback new Error msg

        else # check filename
            fs.getChildren entry, (err, children) =>
                return callback err if err

                if children.length is 0
                    # it's anormal but download it !
                    log.warn "Missing file #{file.name} on device, fetching it."
                    @getBinary file, noop, callback

                else if children[0].name is fileName
                    callback()
                else # rename the file.
                    fs.moveTo children[0], entry, fileName, callback



    # Remove from cache specified file.
    # @param file a cozy file document.
    removeLocal: (file, callback) ->
        log.info "remove #{file.name} from cache."

        fs.getDirectory @downloads, @fileToEntryName(file), (err, binfolder) =>
            return callback err if err
            fs.rmrf binfolder, (err) =>
                @removeFromCacheList @fileToEntryName(file)
                callback err


    removeLocalFolder: (folder, callback) ->
        @getDbFilesOfFolder folder, (err, files) =>
            return callback err if err

            async.eachSeries files, (file, cb) =>
                @removeLocal file, cb
            , callback


    # Get the entry (if in cache) related to the specified files list.
    # return a list of objects {file, entry}
    # @param docs a list of file or folder documents.
    _filesNEntriesInCache: (docs) ->
        fileNEntriesInCache = []
        for file in docs
            # early created file may not have binary property yet.
            if file.docType.toLowerCase() is 'file' and file.binary?
                entries = @cache.filter (entry) ->
                    entry.name.indexOf(file.binary.file.id) isnt -1
                if entries.length isnt 0
                    fileNEntriesInCache.push
                        file: file
                        entry: entries[0]

        return fileNEntriesInCache


    _replicationFilter: ->
        if @config.get 'cozyNotifications'
            filter = (doc) ->
                return doc.docType?.toLowerCase() is 'folder' or
                    doc.docType?.toLowerCase() is 'file' or
                    doc.docType?.toLowerCase() is 'notification' and
                        doc.type?.toLowerCase() is 'temporary'

        else
            filter = (doc) ->
                return doc.docType?.toLowerCase() is 'folder' or
                    doc.docType?.toLowerCase() is 'file'

        return filter


    # wrapper around _sync to maintain the state of inSync
    sync: (options, callback) ->
        return callback null if @get 'inSync'

        unless @config.has('checkpointed')
            return callback new Error "database not initialized"

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
        @stopRealtime()
        changedDocs = []
        checkpoint = @config.get 'checkpointed'

        replication = @db.replicate.from @config.remote,
            batch_size: 20
            batches_limit: 5
            filter: @_replicationFilter()
            live: false
            since: checkpoint

        replication.on 'change', (change) ->
            log.info "changes received while sync"
            changedDocs = changedDocs.concat change.docs

        replication.once 'error', (err) =>
            log.error "error while replication in sync", err
            if err?.result?.status? and err.result.status is 'aborted'
                replication?.cancel()
                @_sync options, callback
            else
                callback err

        replication.once 'complete', (result) =>
            log.info "replication in sync completed."
            async.eachSeries @_filesNEntriesInCache(changedDocs), \
                    @updateLocal, (err) =>
                # Continue on cache update error, 'syncCache' call on next
                # backup may fix it.
                log.warn err if err
                @config.save checkpointed: result.last_seq, (err) =>
                    callback err
                    unless options.background
                        app.router.forceRefresh()
                        # updateIndex In background
                        @updateIndex =>
                            @startRealtime()

    # realtime
    # start from the last checkpointed value
    # smaller batches to limit memory usage
    # if there is an error, we keep trying
    # with exponential backoff 2^x s (max 1min)
    #
    realtimeBackupCoef = 1

    startRealtime: =>
        if @liveReplication or not app.foreground
            return

        unless @config.has('checkpointed')
            log.error new Error "database not initialized"

            if confirm t 'Database not initialized. Do it now ?'
                app.router.navigate 'first-sync', trigger: true
                @resetSynchro (err) ->
                    if err
                        log.error err
                        return alert err.message

            return


        log.info 'REALTIME START'

        @liveReplication = @db.replicate.from @config.remote,
            batch_size: 20
            batches_limit: 5
            filter: @_replicationFilter()
            since: @config.get 'checkpointed'
            live: true

        @liveReplication.on 'change', (change) =>
            realtimeBackupCoef = 1
            app.router.forceRefresh()

            @set 'inSync', true
            fileNEntriesInCache = @_filesNEntriesInCache change.docs
            async.eachSeries fileNEntriesInCache, @updateLocal, (err) ->
                if err
                    log.error err
                else
                    log.info "updated binary in realtime"


        @liveReplication.on 'uptodate', (e) =>
            realtimeBackupCoef = 1
            @set 'inSync', false
            app.router.forceRefresh()
            # @TODO : save last_seq ?
            log.info "UPTODATE realtime", e

        @liveReplication.once 'complete', (e) =>
            log.info "REALTIME CANCELLED"
            @set 'inSync', false
            @liveReplication = null

        @liveReplication.once 'error', (e) =>
            @liveReplication = null

            realtimeBackupCoef++ if realtimeBackupCoef < 6
            timeout = 1000 * (1 << realtimeBackupCoef)
            log.error "REALTIME BROKE, TRY AGAIN IN #{timeout} #{e.toString()}"
            @realtimeBackOff = setTimeout @startRealtime, timeout

    stopRealtime: =>
        # Stop replication.
        @liveReplication?.cancel()

        # Kill backoff if exists.
        clearTimeout @realtimeBackOff


    # Update cache files with outdated revisions. Called while backup
    syncCache:  (callback) =>
        @set 'backup_step', 'cache_sync'
        @set 'backup_step_done', null

        # TODO: Add optimizations on db.query : avoid include_docs on big list.
        options =
            keys: @cache.map (entry) -> return entry.name.split('-')[0]
            include_docs: true

        @db.query DesignDocuments.BY_BINARY_ID, options, (err, results) =>
            return callback err if err
            toUpdate = @_filesNEntriesInCache results.rows.map (row) -> row.doc

            processed = 0
            @set 'backup_step', 'cache_sync'
            @set 'backup_step_total', toUpdate.length
            async.eachSeries toUpdate, (fileNEntry, cb) =>
                @set 'backup_step_done', processed++
                @updateLocal fileNEntry, cb
            , callback

