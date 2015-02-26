request = require '../lib/request'
fs = require './filesystem'
makeDesignDocs = require './replicator_mapreduce'
ReplicatorConfig = require './replicator_config'
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
        # remove all files/folders then call initialReplication
        @initialReplication callback

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

    getDbFilesOfFolder: (folder, callback) ->
        path = folder.path
        options =
            startkey: if path then ['/' + path] else ['']
            endkey: if path then ['/' + path, {}] else ['', {}]
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

            if response?.statusCode isnt 200
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
                # TODO
                (cb) => @copyView 'notification', cb
                (cb) => @set('initialReplicationStep', 2) and cb null
                # (cb) => @set('initialReplicationStep', 2) and cb null
                # Save last sequences
                (cb) => @config.save checkpointed: last_seq, cb
                # build the initial state of FilesAndFolder view index
                (cb) => @db.query 'FilesAndFolder', {}, cb
                # TODO
                (cb) => @db.query 'Notifications', {}, cb

            ], (err) =>
                console.log "end of inital replication #{Date.now()}"
                @set 'initialReplicationStep', 3
                callback err
                # updateIndex In background
                @updateIndex -> console.log "Index built"


    copyView: (model, callback) ->
        console.log "copyView #{Date.now()}"
        options = @config.makeUrl "/_design/#{model}/_view/all/"
        request.get options, (err, res, body) =>
            return callback err if err
            return callback null unless body.rows?.length
            async.eachSeries body.rows, (doc, cb) =>
                doc = doc.value
                @db.put doc, 'new_edits':false, (err, file) =>
                    cb()
            , callback

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

    # wrapper around _sync to maintain the state of inSync
    sync: (callback) ->
        return callback null if @get 'inSync'
        console.log "SYNC CALLED"
        @set 'inSync', true
        @_sync {}, (err) =>
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
        @liveReplication?.cancel()
        checkpoint = options.checkpoint or @config.get 'checkpointed'

        replication = @db.replicate.from @config.remote,
            batch_size: 20
            batches_limit: 5
            filter: (doc) ->
                return doc.docType is 'Folder' or
                    doc.docType is 'File' or
                    doc.docType is 'Notification'
            live: false
            since: checkpoint

        replication.on 'change', (change) ->
            console.log "REPLICATION CHANGE : #{change}"

        replication.once 'error', (err) =>
            console.log "REPLICATOR ERROR #{JSON.stringify(err)} #{err.stack}"
            if err?.result?.status? and err.result.status is 'aborted'
                replication?.cancel()
                @_sync options, callback
            else
                callback err

        replication.once 'complete', (result) =>
            console.log "REPLICATION COMPLETED"
            @config.save checkpointed: result.last_seq, (err) =>
                callback err
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
        return if @liveReplication
        console.log 'REALTIME START'
        @liveReplication = @db.replicate.from @config.remote,
            batch_size: 20
            batches_limit: 5
            filter: (doc) ->
                return doc.docType is 'Folder' or
                    doc.docType is 'File' or
                    doc.docType is 'Notification'
            since: @config.get 'checkpointed'
            continuous: true

        @liveReplication.on 'change', (e) =>
            realtimeBackupCoef = 1
            event = new Event 'realtime:onChange'
            window.dispatchEvent event
            @set 'inSync', true

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
            @startRealtime()

        @liveReplication.once 'error', (e) =>
            @liveReplication = null
            realtimeBackupCoef++ if realtimeBackupCoef < 6
            timeout = 1000 * (1 << realtimeBackupCoef)
            console.log "REALTIME BROKE, TRY AGAIN IN #{timeout} #{e.toString()}"
            setTimeout @startRealtime, timeout
