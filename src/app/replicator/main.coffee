async = require 'async'
ChangeDispatcher = require './change/change_dispatcher'
Db = require '../lib/database'
DesignDocuments = require './design_documents'
DeviceStatus = require '../lib/device_status'
FileCacheHandler = require '../lib/file_cache_handler'
FilterManager = require './filter_manager'
fs = require './filesystem'
ReplicationLauncher = require "./replication_launcher"

log = require('../lib/persistent_log')
    prefix: "replicator main"
    date: true


#Replicator extends Model to watch/set inBackup, inSync
module.exports = class Replicator extends Backbone.Model

    db: null
    config: null

    # backup images functions are in replicator_backups
    _.extend Replicator.prototype, require './replicator_backups'

    _.extend Replicator.prototype, require '../migrations/replicator_migration'

    defaults: ->
        inSync: false
        inBackup: false


    initFileSystem: (callback) ->
        fs.initialize (err, downloads, cache) =>
            return callback err if err
            @downloads = downloads
            @cache = cache
            callback()


    initConfig: (@config, @requestCozy, @database, @fileCacheHandler) ->
        @db = @database.replicateDb
        @photosDB = @database.localDb


    # pings the cozy to check the credentials without creating a device
    checkCredentials: (url, password, callback) ->
        options =
            method: 'post'
            url: "#{url}/login"
            retry: 3
            json:
                username: 'owner'
                password: password
            auth: false
        window.app.init.requestCozy.request options, (err, response, body) ->
            if err and err.message is "Unexpected token <"
                error = t err.message
            else if err
                # Unexpected error, just show it to the user.
                log.error err
                error = err.message
                if error.indexOf('CORS request rejected') isnt -1
                    error = t 'connexion error'
            else if response?.status is 0
                error = t 'connexion error'
            else if body?.error is "error otp invalid code"
                error = null
            else if response?.statusCode isnt 200
                error = err?.message or body.error or body.message
            else
                error = null

            callback error

    registerRemoteSafe: (url, password, deviceName, callback, num = 0) ->
        name = deviceName
        name += "-#{num}" if num > 0
        log.debug 'deviceName', name
        @_registerRemote url, password, name, (err, body) =>
            if err and err.message is 'device name already exist'
                console.info 'The above 400 is totally normal. Device name \
                    already exist, we test another'
                @registerRemoteSafe url, password, deviceName, callback, num + 1
            else
                callback err, body

    _registerRemote: (url, password, deviceName, callback) ->
        options =
            method: "post"
            url: "#{url}/device"
            retry: 3
            auth:
                username: 'owner'
                password: password
            json:
                login: deviceName
                permissions: @config.get 'devicePermissions'
        @requestCozy.request options, (err, response, body) ->
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
                callback err, body


    updatePermissions: (password, callback) ->
        options =
            method: 'put'
            url: "#{@config.getCozyUrl()}/device/#{@config.get('deviceName')}"
            retry: 3
            auth:
                username: 'owner'
                password: password
            json:
                login: @config.get 'deviceName'
                permissions: app.init.config.getDefaultPermissions()
        @requestCozy.request options, (err, response, body) =>
            return callback err if err

            @config.set 'devicePermissions', body.permissions, callback


    takeCheckpoint: (callback) ->
        options =
            retry: 3
            method: 'get'
            type: 'replication'
            path: '/_changes?descending=true&limit=1'
        @requestCozy.request options, (err, res, body) ->
            return callback err if err
            window.app.checkpointed = body.last_seq
            callback()


    # Fetch all documents, with a previously put couchdb view.
    _fetchAll: (doc, callback) ->
        options =
            method: 'post'
            type: 'data-system'
            path: "/request/#{doc.docType}/all/"
            body:
                include_docs: true
                show_revs: true
            retry: doc.retry
        @requestCozy.request options, (err, res, rows) ->
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
            return callback err if err
            return callback null, [] unless rows?.length isnt 0

            total = rows.length
            count = 1
            msg = 'saving_in_app'
            # 2. Put in PouchDB
            async.mapSeries rows, (row, cb) =>
                if app.layout.currentView.changeCounter
                    app.layout.currentView.changeCounter count++, total, msg
                doc = row.doc

                # 2.1 Fetch attachment if needed (typically contact docType)
                if options.attachments is true and doc._attachments?
                # TODO? needed : .picture?
                    requestOptions =
                        method: 'get'
                        type: 'replication'
                        path: "/#{doc._id}?attachments=true"
                        retry: 3
                    @requestCozy.request requestOptions, (err, res, body) ->
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
        log.debug "updateIndex"

        count = 0
        call = ->
            count++
            if count is 2
                callback()

        # build pouch's map indexes
        @db.query DesignDocuments.FILES_AND_FOLDER, {}, call

        # build pouch's map indexes
        @db.query DesignDocuments.LOCAL_PATH, {}, call

# END initialisations methods

# BEGIN Cache methods



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
            return callback() if results.rows.length is 0
            callback null, _.every results.rows, (row) ->
                row.value in fsCacheFolder


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
                    navigator.notification.alert t 'not enough space'
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
                        @fileCacheHandler.getBinary file, pb, cb
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


    removeLocalFolder: (folder, callback) ->
        @_getDbFilesOfFolder folder, (err, files) =>
            return callback err if err

            async.eachSeries files, (file, cb) =>
                @fileCacheHandler.removeLocal file, cb
            , callback


    # wrapper around startRealtime to maintain the state of inSync
    sync: (options, callback) ->
        return callback() if @get 'inSync'

        log.info "start a sync"
        @set 'inSync', true
        options.live = false
        @startRealtime options, (err) =>
            @set 'inSync', false
            if err?.status is 404
                console.info 'The above 404 is not normal, but we retest with \
                              smallest pouch last_seq (remoteCheckpoint).'

                @checkpointLoop ?= 0
                @checkpointLoop++

                if @checkpointLoop > 10
                    return callback()
                else
                    options.remoteCheckpoint--
                    return @sync options, callback

            callback err


    ###*
     * Start real time replication
    ###
    startRealtime: (options = live: true, callback = ->) =>
        log.info "startRealtime, #{JSON.stringify options}"

        @stopRealtime() if @replicationLauncher

        @filterManager ?= new FilterManager @config, @requestCozy, @db

        @filterManager.filterRemoteExist =>
            @replicationLauncher = new ReplicationLauncher @database, \
                app.router, @filterManager.getFilterName(), @config
            @replicationLauncher.start options, (err) =>
                log.warn err if err
                @stopRealtime()
                callback.apply @, arguments

    # Stop replication.
    stopRealtime: =>
        log.info "stopRealtime"

        @replicationLauncher?.stop()
        delete @replicationLauncher

    # Update cache files with outdated revisions. Called while backup<
    syncCache:  (callback) ->
        @set 'backup_step', 'files_sync'
        @set 'backup_step_total', null
        @set 'backup_step_done', null

        DeviceStatus.checkReadyForSync (err, ready, msg) =>
            return callback() unless ready
            @fileCacheHandler.downloadUnsynchronizedFiles callback
