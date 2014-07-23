request = require '../lib/request'
fs = require './filesystem'
basic = require '../lib/basic'
makeDesignDocs = require './replicator_mapreduce'
DBNAME = "cozy-files.db"
DBCONTACTS = "cozy-contacts.db"
DBOPTIONS = if window.isBrowserDebugging then {} else adapter: 'websql'

#Replicator extends Model to watch/set inBackup, inSync
module.exports = class Replicator extends Backbone.Model

    db: null
    config: null

    # backup functions (contacts & images) are in replicator_backups
    _.extend Replicator.prototype, require './replicator_backups'

    destroyDB: (callback) ->
        @db.destroy (err) =>
            return callback err if err
            @contactsDB.destroy (err) =>
                return callback err if err
                fs.rmrf @downloads, callback

    init: (callback) ->
        fs.initialize (err, downloads, cache) =>
            return callback err if err
            @downloads = downloads
            @cache = cache
            @db = new PouchDB DBNAME, DBOPTIONS
            @contactsDB = new PouchDB DBCONTACTS, DBOPTIONS
            makeDesignDocs @db, @contactsDB, (err) =>
                return callback err if err
                @db.get 'localconfig', (err, config) =>
                    if err
                        callback null, null
                    else
                        @config = config
                        @remote = @createRemotePouchInstance()
                        console.log @config.fullRemoteURL
                        console.log @config.deviceId
                        console.log @config.checkpointed
                        callback null, config

    createRemotePouchInstance: ->
        # This is ugly because we extract a reference to
        # the host object to monkeypatch pouchdb#2517
        # @TODO fix me when fixed upstream
        # https://github.com/pouchdb/pouchdb/issues/2517

        @host =
            remote: true
            protocol: 'https'
            host: @config.cozyURL
            port: 443
            path: ''
            db: 'cozy'
            headers: Authorization: basic @config.auth

        options =
            name: @config.fullRemoteURL
            getHost: => @host

        new PouchDB options

    getDbFilesOfFolder: (folder, callback) ->
        path = folder.path + '/' + folder.name
        options =
            include_docs: true
            startkey: path
            endkey: path + '\uffff'

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
                config.password = body.password
                config.deviceId = body.id
                config.syncContacts = false
                config.syncImages = true
                config.syncOnWifi = true
                config.auth =
                    username: config.deviceName
                    password: config.password

                config.fullRemoteURL =
                    "https://#{config.deviceName}:#{config.password}" +
                    "@#{config.cozyURL}/cozy"

                @config = config
                @remote = new PouchDB @config.fullRemoteURL
                @config._id = 'localconfig'
                @saveConfig callback

    saveConfig: (callback) ->
        @db.put @config, (err, result) =>
            return callback err if err
            unless result.ok
                msg = "Cant save config"
                msg += JSON.stringify @config
                msg += JSON.stringify result
                return callback new Error msg

            @config._id = result.id
            @config._rev = result.rev
            callback null

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


    initialReplication: (progressback, callback) ->
        url = "#{@config.fullRemoteURL}/_changes?descending=true&limit=1"
        auth = @config.auth
        progressback 0
        request.get {url, auth, json: true}, (err, res, body) =>
            return callback err if err

            # we store last_seq before copying files & folder
            # to avoid losing changes occuring during replicatation
            last_seq = body.last_seq
            progressback 1/4
            async.series [
                (cb) => @copyView 'file', cb
                (cb) => progressback(2/4) and cb null
                (cb) => @copyView 'folder', cb
                (cb) => progressback(3/4) and cb null
                (cb) =>
                    @config.checkpointed = last_seq
                    @saveConfig cb
            ], (err) ->
                callback err
                # updateIndex In background
                @updateIndex -> console.log "Index built"

    copyView: (model, callback) ->
        url = "#{@config.fullRemoteURL}/_design/#{model}/_view/all/"
        auth = @config.auth
        request.get {url, auth, json:true}, (err, res, body) =>
            return callback err if err

            docs = body.rows.map (row) -> row.value
            @db.bulkDocs docs, callback


    binaryInCache: (binary_id) =>
        @cache.some (entry) -> entry.name is binary_id

    folderInCache: (folder, callback) =>
        @getDbFilesOfFolder folder, (err, files) =>
            return callback err if err
            # a folder is in cache if all its children are in cache
            callback null, _.every files, (file) =>
                @binaryInCache file.binary.file.id

    getBinary: (model, callback, progressback) ->
        binary_id = model.binary.file.id

        fs.getOrCreateSubFolder @downloads, binary_id, (err, binfolder) =>
            return callback err if err
            unless model.name
                return callback new Error('no model name :' + JSON.stringify(model))

            fs.getFile binfolder, model.name, (err, entry) =>
                return callback null, entry.toURL() if entry

                # getFile failed, let's download
                url = encodeURI "https://#{@config.cozyURL}/cozy/#{binary_id}/file"
                path = binfolder.toURL() + '/' + model.name
                auth = @config.auth

                fs.download url, path, auth, progressback, (err, entry) =>
                    if err
                        # failed to download
                        fs.delete binfolder, (delerr) ->
                            #@TODO handle delerr
                            callback err
                    else
                        @cache.push binfolder
                        callback null, entry.toURL()

    getBinaryFolder: (folder, callback, progressback) ->
        @getDbFilesOfFolder folder, (err, files) =>
            return callback err if err

            totalSize = files.reduce ((sum, file) -> sum + file.size), 0

            fs.freeSpace (err, available) =>
                return callback err if err
                if totalSize > available * 1024 # available is in KB
                    alert 'There is not enough disk space, try download sub-folders.'
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
                        @getBinary file, cb, pb
                    , (err) ->
                        return callback err if err
                        app.router.bustCache(folder.path + '/' + folder.name)
                        callback()


    removeLocal: (model, callback) ->
        binary_id = model.binary.file.id
        console.log "REMOVE LOCAL"
        console.log binary_id

        fs.getDirectory @downloads, binary_id, (err, binfolder) =>
            return callback err if err
            fs.rmrf binfolder, (err) =>
                # remove from @cache
                for entry, index in @cache when entry.name is binary_id
                    @cache.splice index, 1
                    break
                callback null

    removeLocalFolder: (folder, callback) ->
         @getDbFilesOfFolder folder, (err, files) =>
            return callback err if err

            async.eachSeries files, (file, cb) =>
                @removeLocal file, cb
            , (err) ->
                return callback err if err
                app.router.bustCache(folder.path + '/' + folder.name)
                callback()

    # wrapper around _sync to maintain the state of inSync
    sync: (callback) ->
        return callback null if @get 'inSync'
        @set 'inSync', true
        @_sync (err) =>
            @set 'inSync', false
            callback err


    _sync: (callback) ->
        console.log "BEGIN SYNC"

        replication = @db.replicate.from @remote,
            batch_size: 50
            batches_limit: 5
            filter: "#{@config.deviceId}/filter"
            since: @config.checkpointed

        # replication.on 'change', (info) ->
        #     console.log "change #{JSON.stringify(info)}"

        replication.once 'error', (err) ->
            console.log "THIS HAPPENS #{JSON.stringify(err)} #{err.stack}"
            callback err

        replication.once 'complete', (result) =>
            console.log "REPLICATION COMPLETED"
            @config.checkpointed = result.last_seq
            @saveConfig (err) =>
                console.log "CONFIG SAVED"
                callback err
                # updateIndex In background
                @updateIndex ->
