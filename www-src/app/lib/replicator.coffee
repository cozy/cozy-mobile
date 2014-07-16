request = require './request'
basic = require './basic'
fs = require './filesystem'
DBNAME = "cozy-files.db"

module.exports = class Replicator

    db: null
    server: null
    config: null

    destroyDB: (callback) ->
        @db.destroy (err) =>
            return callback err if err
            fs.rmrf @downloads

    init: (callback) ->
        @initDownloadFolder (err) =>
            return callback err if err
            options = if window.isBrowserDebugging then {} else adapter: 'websql'
            @db = new PouchDB DBNAME, options
            @db.get 'localconfig', (err, config) =>
                if err
                    console.log err
                    callback null, null
                else
                    @config = config
                    callback null, config

    initDownloadFolder: (callback) ->
        fs.initialize (err, filesystem) =>
            return callback err if err
            window.FileTransfer.fs = filesystem
            fs.getOrCreateSubFolder filesystem.root, 'cozy-downloads', (err, downloads) =>
                return callback err if err
                @downloads = downloads
                fs.getChildren downloads, (err, children) =>
                    return callback err if err
                    @cache = children
                    callback null

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
                config.auth =
                    username: config.deviceName
                    password: config.password

                config.fullRemoteURL =
                    "https://#{config.deviceName}:#{config.password}" +
                    "@#{config.cozyURL}/cozy"

                @config = config
                @config._id = 'localconfig'
                @saveConfig callback

    saveConfig: (callback) ->
        @db.put @config, (err, result) =>
            return callback err if err
            return callback new Error(JSON.stringify(result)) unless result.ok
            @config._id = result.id
            @config._rev = result.rev
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
            @copyView 'file', (err) =>
                return callback err if err

                progressback 2/4
                @copyView 'folder', (err) =>
                    return callback err if err

                    progressback 3/4
                    @config.checkpointed = last_seq
                    @saveConfig callback

    copyView: (model, callback) ->
        url = "#{@config.fullRemoteURL}/_design/#{model}/_view/all/"
        auth = @config.auth
        request.get {url, auth, json:true}, (err, res, body) =>
            return callback err if err

            async.each body.rows, (row, cb) =>
                @db.put row.value, cb
            , callback


    binaryInCache: (binary_id) =>
        @cache.some (entry) -> entry.name is binary_id

    folderInCache: (folder, callback) =>
        @db.query binariesInFolder(folder), {}, (err, result) =>
            return callback err if err
            ids = result.rows.map (row) -> row.value.binary.file.id
            # a folder is in cache if all its children are in cache
            callback null, _.every ids, @binaryInCache

    getBinary: (model, callback, progressback) ->
        binary_id = model.binary.file.id

        fs.getOrCreateSubFolder @downloads, binary_id, (err, binfolder) =>
            return callback err if err
            return callback new Error('no model name :' + JSON.stringify(model)) unless model.name

            fs.getFile binfolder, model.name, (err, entry) =>
                return callback null, entry.toURL() if entry

                # getFile failed, let's download
                options =
                    from: encodeURI "https://#{@config.cozyURL}/cozy/#{binary_id}/file"
                    headers: Authorization: basic @config.deviceName, @config.password
                    to: binfolder.toURL() + '/' + model.name

                fs.download options, progressback, (err, entry) =>
                    if err
                        # failed to download
                        fs.delete binfolder, (delerr) ->
                            #@TODO handle delerr
                            callback err
                    else
                        @cache.push binfolder
                        callback null, entry.toURL()

    getBinaryFolder: (folder, callback, progressback) ->
        @db.query binariesInFolder(folder), {}, (err, result) =>
            return callback err if err

            sizes = result.rows.map (row) -> row.value.size
            totalSize = sizes.reduce (a,b) -> a + b

            fs.freeSpace (err, available) ->
                return callback err if err
                if totalSize > available * 1024 # available is in KB
                    alert 'There is not enough disk space, try download sub-folders.'
                    callback null
                else

                    progressHandlers = {}
                    reportProgress = ->
                        total = done = 0
                        for key, status of progressHandlers
                            done += status[0]
                            total += status[1]
                        progressback done, total


                    async.each result.rows, (row, cb) =>
                        console.log "DOWNLOAD", row.name
                        @getBinary row.value, cb, (done, total) ->
                            progressHandlers[row.value._id] = [done, total]
                            reportProgress()

                    , ->
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
         @db.query binariesInFolder(folder), {}, (err, result) =>
            return callback err if err
            ids = result.rows.map (row) -> row.value.binary.file.id

            async.eachSeries ids, (id, cb) =>
                @removeLocal binary:file:id: id, cb
            , (err) ->
                return callback err if err
                app.router.bustCache(folder.path + '/' + folder.name)
                callback()


    sync: (callback) ->
        @db.replicate.from @config.fullRemoteURL,
            filter: "#{@config.deviceId}/filter"
            since: @config.checkpointed
            complete: (err, result) =>
                @config.checkpointed = result.last_seq
                @saveConfig callback

binariesInFolder = (folder) ->
    path = folder.path + '/' + folder.name
    # console.log "bif" + path
    return (doc, emit) ->
        if doc.docType?.toLowerCase() is 'file' and doc.path.indexOf(path) is 0
            emit doc._id, doc
