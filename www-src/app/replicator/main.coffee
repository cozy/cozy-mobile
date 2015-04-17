request = require '../lib/request'
fs = require './filesystem'
makeDesignDocs = require './replicator_mapreduce'
ReplicatorConfig = require './replicator_config'
DeviceStatus = require '../lib/device_status'
DBNAME = "cozy-files.db"
DBCONTACTS = "cozy-contacts.db"
DBPHOTOS = "cozy-photos.db"
DBOPTIONS = if window.isBrowserDebugging then {} else adapter: 'websql'

#Replicator extends Model to watch/set inBackup, inSync
module.exports = class Replicator extends Backbone.Model

    db: null
    config: null

    # backup functions (contacts & images) are in replicator_backups
    _.extend Replicator.prototype, require './replicator_backups'

    defaults: ->
        inSync: false
        inBackup: false

    destroyDB: (callback) ->
        @db.destroy (err) =>
            return callback err if err
            @contactsDB.destroy (err) =>
                return callback err if err
                @photosDB.destroy (err) =>
                    return callback err if err
                    fs.rmrf @downloads, callback

    resetSynchro: (callback) ->
        @stopRealtime()
        # remove all files/folders then call initialReplication
        @initialReplication (err) =>
            @startRealtime()
            callback err


    init: (callback) ->
        fs.initialize (err, downloads, cache) =>
            return callback err if err
            @downloads = downloads
            @cache = cache
            @db = new PouchDB DBNAME, DBOPTIONS
            @contactsDB = new PouchDB DBCONTACTS, DBOPTIONS
            @photosDB = new PouchDB DBPHOTOS, DBOPTIONS
            makeDesignDocs @db, @contactsDB, @photosDB, (err) =>
                return callback err if err
                @config = new ReplicatorConfig(this)
                @config.fetch callback

    # Find all files in (recursively) the specified folder.
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

    registerRemote: (config, callback) ->
        request.post
            uri: "https://#{config.cozyURL}/device/",
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
                        "https://#{config.deviceName}:#{body.password}" +
                        "@#{config.cozyURL}/cozy"

                @config.save config, callback

    # pings the cozy to check the credentials without creating a device
    checkCredentials: (config, callback) ->
        request.post
            uri: "https://#{config.cozyURL}/login"
            json:
                username: 'owner'
                password: config.password
        , (err, response, body) ->
            if response?.status is 0
                error = t 'connexion error'

            else if response?.statusCode isnt 200
                error = err?.message or body.error or body.message

            else
                error = null

            callback error

    updateIndex: (callback) ->
        # build the search index
        @db.search
            build: true
            fields: ['name']
        , (err) =>
            console.log "INDEX BUILT"
            console.log err if err
            # build pouch's map indexes
            @db.query 'FilesAndFolder', {}, =>
                # build pouch's map indexes
                @db.query 'LocalPath', {}, ->
                    callback null

    initialReplication: (callback) ->
        console.log "initialReplication"
        @set 'initialReplicationStep', 0
        options = @config.makeUrl '/_changes?descending=true&limit=1'
        request.get options, (err, res, body) =>
            return callback err if err
            # we store last_seq before copying files & folder
            # to avoid losing changes occuring during replication
            last_seq = body.last_seq
            async.series [
                # Force checkpoint to 0
                (cb) => @copyView 'file', cb
                #(cb) => @config.save checkpointed: 0, cb
                (cb) => @set('initialReplicationStep', 1) and cb null
                (cb) => @copyView 'folder', cb
                # TODO: it copies all notifications (persistent ones too).
                (cb) => @copyView 'notification', cb

                # TODO
                (cb) => @copyView 'contact', cb
                (cb) => @config.save contactsPullCheckpointed: last_seq, cb
                # END TODO

                (cb) => @set('initialReplicationStep', 2) and cb null
                # Save last sequences
                (cb) => @config.save checkpointed: last_seq, cb
                # build the initial state of FilesAndFolder view index
                (cb) => @db.query 'FilesAndFolder', {}, cb
                (cb) => @db.query 'NotificationsTemporary', {}, cb

            ], (err) =>
                console.log "end of inital replication #{Date.now()}"
                @set 'initialReplicationStep', 3
                callback err
                # updateIndex In background
                @updateIndex -> console.log "Index built"


    copyView: (model, callback) ->
        console.log "copyView #{Date.now()}"

        # To get around case problems and various cozy's generations,
        # try view _view/files-all, if it doesn't exist, use _view/all.
        if model in ['file', 'folder']
            options = @config.makeUrl "/_design/#{model}/_view/files-all/"
            options2 = @config.makeUrl "/_design/#{model}/_view/all/"
        else
            options = @config.makeUrl "/_design/#{model}/_view/all/"


        handleResponse = (err, res, body) =>

            if not err and res.status > 399
                console.log res
                err = new Error res.statusText

            return callback err if err
            return callback null unless body.rows?.length
            async.eachSeries body.rows, (doc, cb) =>
                doc = doc.value
                @db.put doc, 'new_edits':false, (err, file) =>
                    cb()
            , callback

        request.get options, (err, res, body) ->
            if res.status is 404 and model in ['file', 'folder']
                request.get options2, handleResponse

            else
                handleResponse(err, res, body)


    fileInFileSystem: (file) =>
        if file.docType.toLowerCase() is 'file'
            @cache.some (entry) ->
                entry.name.indexOf(file.binary.file.id) isnt -1


    fileVersion: (file) =>
        if file.docType.toLowerCase() is 'file'
            @cache.some (entry) ->
                entry.name is file.binary.file.id + '-' + file.binary.file.rev


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



    getBinary: (model, progressback, callback) ->
        binary_id = model.binary.file.id
        binary_rev = model.binary.file.rev
        fs.getOrCreateSubFolder @downloads, binary_id + '-' + binary_rev, (err, binfolder) =>
            return callback err if err and err.code isnt FileError.PATH_EXISTS_ERR
            unless model.name
                return callback new Error('no model name :' + JSON.stringify(model))

            fs.getFile binfolder, model.name, (err, entry) =>
                return callback null, entry.toURL() if entry

                # getFile failed, let's download
                options = @config.makeUrl "/#{binary_id}/file"
                options.path = binfolder.toURL() + '/' + model.name

                fs.download options, progressback, (err, entry) =>
                    if err?.message? and err.message is "This file isnt available offline" and
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
                        @removeAllLocal binary_id, binary_rev

    getBinaryFolder: (folder, progressback, callback) ->
        @getDbFilesOfFolder folder, (err, files) =>
            return callback err if err

            totalSize = files.reduce ((sum, file) -> sum + file.size), 0

            fs.freeSpace (err, available) =>
                return callback err if err
                if totalSize > available * 1024 # available is in KB
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
                        console.log "DOWNLOAD #{file.name}"
                        pb = reportProgress.bind null, file._id
                        @getBinary file, pb, cb
                    , callback

    removeAllLocal: (id, rev) ->
        @cache.some (entry) =>
            if entry.name.indexOf(id) isnt -1 and
                entry.name isnt id + '-' + rev
                    fs.getDirectory @downloads, entry.name, (err, binfolder) =>
                        return callback err if err
                        fs.rmrf binfolder, (err) =>
                            # remove from @cache
                            for currentEntry, index in @cache when currentEntry.name is entry.name
                                @cache.splice index, 1
                                break

    # Update the local copy  (options.entry) of the file (options.file)
    updateLocal: (options, callback) =>
        file = options.file
        entry = options.entry

        if file._deleted
            @removeLocal file, callback

        # check binary revs
        else if entry.name isnt file.binary.file.id + '-' + file.binary.file.rev
            # Don't update the binary if "no wifi"
            DeviceStatus.checkReadyForSync (err, ready, msg) =>
                if ready
                    # Download the new version.
                    noop = ->
                    @getBinary file, noop, callback
                else
                    callback()

        else # check filename
            fs.getChildren entry, (err, children) =>
                if not err? and children.length is 0
                    err = new Error 'File is missing'
                return callback err if err

                child = children[0]
                if child.name is file.name
                    callback()
                else
                    fs.moveTo child, entry, file.name, callback


    removeLocal: (model, callback) ->
        binary_id = model.binary.file.id
        binary_rev = model.binary.file.rev
        console.log "REMOVE LOCAL"
        console.log binary_id

        fs.getDirectory @downloads, binary_id + '-' + binary_rev, (err, binfolder) =>
            return callback err if err
            fs.rmrf binfolder, (err) =>
                # remove from @cache
                for entry, index in @cache when entry.name is binary_id + '-' + binary_rev
                    @cache.splice index, 1
                    break
                callback null


    removeLocalFolder: (folder, callback) ->
         @getDbFilesOfFolder folder, (err, files) =>
            return callback err if err

            async.eachSeries files, (file, cb) =>
                @removeLocal file, cb
            , callback


    # Get the entry (if in cache) related to the specified files list.
    # return a list of objects {file, entry}
    _filesNEntriesInCache: (docs) ->
        fileNEntriesInCache = []
        for file in docs
            if file.docType.toLowerCase() is 'file'
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
        console.log "SYNC CALLED"
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
        console.log "BEGIN SYNC"
        total_count = 0
        @stopRealtime()
        changedDocs = []
        checkpoint = options.checkpoint or @config.get 'checkpointed'

        replication = @db.replicate.from @config.remote,
            batch_size: 20
            batches_limit: 5
            filter: @_replicationFilter()
            live: false
            since: checkpoint

        replication.on 'change', (change) =>
            console.log "REPLICATION CHANGE"
            changedDocs = changedDocs.concat change.docs

        replication.once 'error', (err) =>
            console.log "REPLICATOR ERROR #{JSON.stringify(err)} #{err.stack}"
            if err?.result?.status? and err.result.status is 'aborted'
                replication?.cancel()
                @_sync options, callback
            else
                callback err

        replication.once 'complete', (result) =>
            console.log "REPLICATION COMPLETED"
            async.eachSeries @_filesNEntriesInCache(changedDocs), \
              @updateLocal, (err) =>
                # Continue on cache update error, 'syncCache' call on next
                # backup may fix it.
                console.log err if err
                @config.save checkpointed: result.last_seq, (err) =>
                    callback err
                    unless options.background
                        app.router.forceRefresh()
                        # updateIndex In background
                        @updateIndex =>
                            console.log 'start Realtime'
                            @startRealtime()

    # realtime
    # start from the last checkpointed value
    # smaller batches to limit memory usage
    # if there is an error, we keep trying
    # with exponential backoff 2^x s (max 1min)
    #
    realtimeBackupCoef = 1

    startRealtime: =>
        # TODO : STUB !
        return

        if @liveReplication or not app.foreground
            return

        console.log 'REALTIME START'

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
            async.eachSeries fileNEntriesInCache, @updateLocal, =>
                console.log "FILES UPDATED"


        @liveReplication.on 'uptodate', (e) =>
            realtimeBackupCoef = 1
            @set 'inSync', false
            app.router.forceRefresh()
            # @TODO : save last_seq ?
            console.log "UPTODATE", e

        @liveReplication.once 'complete', (e) =>
            console.log "LIVE REPLICATION CANCELLED"
            @set 'inSync', false
            @liveReplication = null

        @liveReplication.once 'error', (e) =>
            @liveReplication = null
            realtimeBackupCoef++ if realtimeBackupCoef < 6
            timeout = 1000 * (1 << realtimeBackupCoef)
            console.log "REALTIME BROKE, TRY AGAIN IN #{timeout} #{e.toString()}"
            @realtimeBackOff = setTimeout @startRealtime, timeout

    stopRealtime: =>
        # Stop replication.
        @liveReplication?.cancel()

        # Kill backoff if exists.
        clearTimeout @realtimeBackOff

    # Update cache files with outdated revisions.
    syncCache:  (callback) =>
        # TODO: Add optimizations on db.query : avoid include_docs on big list.
        options =
            keys: @cache.map (entry) -> return entry.name.split('-')[0]
            include_docs: true

        @db.query 'ByBinaryId', options, (err, results) =>
            return callback err if err
            toUpdate = @_filesNEntriesInCache results.rows.map (row) -> row.doc
            async.eachSeries toUpdate, @updateLocal, callback
