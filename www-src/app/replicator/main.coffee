request = require '../lib/request'
fs = require './filesystem'
makeDesignDocs = require './replicator_mapreduce'
ReplicatorConfig = require './replicator_config'
DeviceStatus = require '../lib/device_status'
DBNAME = "cozy-files.db"
DBPHOTOS = "cozy-photos.db"


log = require('/lib/persistent_log')
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

    _.extend Replicator.prototype, require './replicator_migration'

    defaults: ->
        inSync: false
        inBackup: false

    initDB: (callback) ->
        if device.version.slice(0, 3) >= '4.4'
            # Migrate to idb
            dbOptions = adapter: 'idb'
            @db = new PouchDB DBNAME, dbOptions
            @photosDB = new PouchDB DBPHOTOS, dbOptions
            @migrateDBs callback

        else #keep sqlite db, no migration.
            dbOptions = adapter: 'websql'
            @db = new PouchDB DBNAME, dbOptions
            @photosDB = new PouchDB DBPHOTOS, dbOptions
            @migrateConfig callback


    init: (callback) ->
        fs.initialize (err, downloads, cache) =>
            return callback err if err
            @downloads = downloads
            @cache = cache
            @initDB (err) =>
                return callback err if err
                makeDesignDocs @db, @photosDB, (err) =>
                    return callback err if err
                    @config = new ReplicatorConfig(this)
                    @config.fetch callback


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


    # Register the device in cozy.
    registerRemote: (config, callback) ->
        request.post
            uri: "#{@config.getScheme()}://#{config.cozyURL}/device/",
            auth:
                username: 'owner'
                password: config.password
            json:
                login: config.deviceName
                type: 'mobile'
        , (err, response, body) =>
            if err
                callback err
            else if response.statusCode is 401 and response.reason
                callback new Error('cozy need patch')
            else if response.statusCode is 401
                callback new Error('wrong password')
            else if response.statusCode is 400
                callback new Error('device name already exist')
            else
                _.extend config,
                    password: body.password
                    deviceId: body.id
                    auth:
                        username: config.deviceName
                        password: body.password
                    fullRemoteURL:
                        "#{@config.getScheme()}://#{config.deviceName}:#{body.password}" +
                        "@#{config.cozyURL}/cozy"

                @config.save config, callback

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

            options = @config.makeUrl '/_changes?descending=true&limit=1'
            request.get options, (err, res, body) =>
                return callback err if err
                # we store last_seq before copying files & folder
                # to avoid losing changes occuring during replication
                last_seq = body.last_seq
                async.series [
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
                    # Save last sequences
                    (cb) => @config.save checkpointed: last_seq, cb
                    # build the initial state of FilesAndFolder view index
                    (cb) => @db.query 'FilesAndFolder', {}, cb
                    (cb) => @db.query 'NotificationsTemporary', {}, cb

                ], (err) =>
                    log.info "end of inital replication"
                    @set 'initialReplicationStep', 5
                    callback err
                    # updateIndex In background
                    @updateIndex -> log.info "Index built"

    # Copy docs of specified model, using couchDB view, initialized by some
    # cozy application (sych as Files, Home, ...).
    copyView: (model, callback) ->
        log.info "enter copyView for #{model}."

        # To get around case problems and various cozy's generations,
        # try view _view/files-all, if it doesn't exist, use _view/all.
        if model in ['file', 'folder']
            options = @config.makeUrl "/_design/#{model}/_view/files-all/"
            options2 = @config.makeUrl "/_design/#{model}/_view/all/"
        else if model in ['notification']
            options = @config.makeUrl "/_design/#{model}/_view/all/"
            options2 = @config.makeUrl "/_design/#{model}/_view/byDate/"
        else
            options = @config.makeUrl "/_design/#{model}/_view/all/"

        handleResponse = (err, res, body) =>
            if not err and res.status > 399
                log.info "Unexpected response: #{res}"
                err = new Error res.statusText
            return callback err if err
            return callback null unless body.rows?.length

            async.eachSeries body.rows, (doc, cb) =>
                doc = doc.value
                @db.put doc, 'new_edits':false, (err, file) =>
                    cb()
            , callback

        request.get options, (err, res, body) ->
            if res.status is 404 and model in ['file', 'folder','notification']
                request.get options2, handleResponse

            else
                handleResponse(err, res, body)


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
            @db.query 'FilesAndFolder', {}, =>
                # build pouch's map indexes
                @db.query 'LocalPath', {}, ->
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
    fileInFileSystem: (file) =>
        if file.docType.toLowerCase() is 'file'
            return @cache.some (entry) ->
                entry.name.indexOf(file.binary.file.id) isnt -1


    fileVersion: (file) =>
        if file.docType.toLowerCase() is 'file'
            @cache.some (entry) =>
                entry.name is @fileToEntryName file


    folderInFileSystem: (path, callback) =>
        options =
            startkey: path
            endkey: path + '\uffff'

        fsCacheFolder = @cache.map (entry) -> entry.name

        @db.query 'PathToBinary', options, (err, results) ->
            return callback err if err
            return callback null, null if results.rows.length is 0
            callback null, _.every results.rows, (row) ->
                row.value in fsCacheFolder


    # Remove specified entry from @cache.
    # @param entry an entry of the @cache to remove.
    removeFromCacheList: (entryName) ->
        for currentEntry, index in @cache \
           when currentEntry.name is entryName
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
                return callback new Error('no model name :' + JSON.stringify(model))

            fs.getFile binfolder, model.name, (err, entry) =>
                return callback null, entry.toURL() if entry

                # getFile failed, let's download
                options = @config.makeUrl "/#{model.binary.file.id}/file"
                options.path = binfolder.toURL() + '/' + model.name

                log.info "download binary of #{model.name}"
                fs.download options, progressback, (err, entry) =>
                    # TODO : Is it reachable code ? https://github.com/cozy/cozy-mobile/commit/7f46ac90c671f0704887bce7d83483c5f323056a
                    if err?.message? and
                       err.message is "This file isnt available offline" and
                       @fileInFileSystem model
                            found = false
                            @cache.some (entry) ->
                                if entry.name.indexOf(binary_id) isnt -1
                                    found = true
                                    callback null, entry.toURL() + '/' + model.name
                            if not found
                                callback err
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
        id =
        async.eachSeries @cache, (entry, cb) =>
            if entry.name.indexOf(file.binary.file.id) isnt -1 and
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

        @db.query 'FilesAndFolder', options, (err, results) ->
            return callback err if err
            docs = results.rows.map (row) -> row.doc
            files = docs.filter (doc) -> doc.docType?.toLowerCase() is 'file'

            callback null, files


    # Update the local copy  (options.entry) of the file (options.file)
    # @param options object with entry and file (cozy doc)
    updateLocal: (options, callback) =>
        file = options.file
        entry = options.entry

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

                else if children[0].name is file.name
                    callback()
                else # rename the file.
                    fs.moveTo children[0], entry, file.name, callback



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
        total_count = 0
        @stopRealtime()
        changedDocs = []
        checkpoint = @config.get 'checkpointed'

        replication = @db.replicate.from @config.remote,
            batch_size: 20
            batches_limit: 5
            filter: @_replicationFilter()
            live: false
            since: checkpoint

        replication.on 'change', (change) =>
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
                # @resetSynchro (err) =>
                #     if err
                #         log.error err
                #         return alert err.message

            return


        log.info 'REALTIME START'

        @liveReplication = @db.replicate.from @config.remote,
            batch_size: 20
            batches_limit: 5
            filter: @_replicationFilter()
            since: @config.get 'checkpointed'
            continuous: true

        @liveReplication.on 'change', (change) =>
            realtimeBackupCoef = 1
            event = new Event 'realtime:onChange'
            window.dispatchEvent event

            @set 'inSync', true
            fileNEntriesInCache = @_filesNEntriesInCache change.docs
            async.eachSeries fileNEntriesInCache, @updateLocal, (err) =>
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

        @db.query 'ByBinaryId', options, (err, results) =>
            return callback err if err
            toUpdate = @_filesNEntriesInCache results.rows.map (row) -> row.doc

            processed = 0
            @set 'backup_step', 'cache_sync'
            @set 'backup_step_total', toUpdate.length
            async.eachSeries toUpdate, (fileNEntry, cb) =>
                @set 'backup_step_done', processed++
                @updateLocal fileNEntry, cb
            , callback

