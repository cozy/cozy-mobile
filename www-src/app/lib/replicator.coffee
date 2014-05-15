request = require './request'
basic = require './basic'
DBNAME = "cozy-files"

REGEXP_PROCESS_STATUS = /Processed (\d+) \/ (\d+) changes/

__chromeSafe = ->
    window.LocalFileSystem = PERSISTENT: window.PERSISTENT
    window.requestFileSystem = (type, size, onSuccess, onError) ->
        size = 5*1024*1024
        navigator.webkitPersistentStorage.requestQuota size, (granted) ->
            window.webkitRequestFileSystem type, granted, onSuccess, onError
        , onError


    window.FileTransfer = class FileTransfer
        download: (url, local, onSuccess, onError, _, options) ->
            xhr = new XMLHttpRequest();
            xhr.open 'GET', url, true
            xhr.overrideMimeType 'text/plain; charset=x-user-defined'
            xhr.responseType = "arraybuffer";
            console.log "HERE", options.headers
            xhr.setRequestHeader key, value for key, value of options.headers
            xhr.onreadystatechange = ->
                return unless xhr.readyState == 4
                FileTransfer.fs.root.getFile local, {create: true}, (entry) ->
                    entry.createWriter (writer) ->
                        writer.onwrite = -> onSuccess entry
                        writer.onerror = (err) -> onError err
                        bb = new BlobBuilder();
                        bb.append(xhr.response);
                        writer.write(bb.getBlob(mimetype));

                    , (err) -> onError err
                , (err) -> onError err
            xhr.send(null)

module.exports = class Replicator

    db: null
    server: null
    config: null

    destroyDB: (callback) ->
        @db.destroy (err) =>
            return callback err if err
            onError = (err) -> callback err
            onSuccess = -> callback null
            @downloads.removeRecursively onSuccess, onError


    init: (callback) ->
        __chromeSafe() if window.isBrowserDebugging
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
        #     @cache = []
        #     return callback null

        onError = (err) -> callback err
        onSuccess = (fs) =>
            window.FileTransfer.fs = fs
            getOrCreateSubFolder fs.root, 'cozy-downloads', (err, downloads) =>
                return callback err if err
                @downloads = downloads
                getChildren downloads, (err, children) =>
                    return callback err if err
                    @cache = children
                    callback null

        if window.isBrowserDebugging # flag for developpement in browser
            size = 5*1024*1024
            navigator.webkitPersistentStorage.requestQuota size, (granted) ->
                window.requestFileSystem LocalFileSystem.PERSISTENT, granted, onSuccess, onError
            , onError

        else
            window.requestFileSystem LocalFileSystem.PERSISTENT, 0, onSuccess, onError

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
            , (err) ->
                return callback err if err
                callback null

    download: (binary_id, local, progressback, callback) ->
        url = encodeURI "https://#{@config.cozyURL}/cozy/#{binary_id}/file"
        ft = new FileTransfer()

        errors = [
            'An error happened (UNKNOWN)',
            'An error happened (NOT FOUND)',
            'An error happened (INVALID URL)',
            'This file isnt available offline',
            'ABORTED'
        ]

        onSuccess = (entry) -> callback null, entry
        onError = (err) -> callback new Error errors[err.code]
        options = headers: Authorization: basic @config.deviceName, @config.password
        ft.onprogress = (e) ->
            if e.lengthComputable then progressback e.loaded, e.total
            else progressback 3, 10 #@TODO, better aproximation

        ft.download url, local, onSuccess, onError, false, options

    getFreeDiskSpace: (callback) ->
        onSuccess = (kBs) -> callback null, kBs * 1024
        cordova.exec onSuccess, callback, 'File', 'getFreeDiskSpace', []


    binaryInCache: (binary_id) =>
        @cache.some (entry) -> entry.name is binary_id

    folderInCache: (folder, callback) =>
        @db.query binariesInFolder(folder), {}, (err, result) =>
            return callback err if err
            ids = result.rows.map (row) -> row.value.binary.file.id
            # console.log "FOLDER IN CACHE " + folder.name + " " + ids.length + " " + ids
            # console.log "     " + @cache.map (entry) -> entry.name
            # console.log "     " + _.every ids, @binaryInCache
            callback null, _.every ids, @binaryInCache

    getBinary: (model, callback, progressback) ->
        binary_id = model.binary.file.id

        getOrCreateSubFolder @downloads, binary_id, (err, binfolder) =>
            return callback err if err
            return callback new Error('no model name :' + JSON.stringify(model)) unless model.name

            getFile binfolder, model.name, (err, entry) =>
                return callback null, entry.toURL() if entry

                # getFile failed, let's download
                local = binfolder.toURL() + '/' + model.name
                @download binary_id, local, progressback, (err, entry) =>
                    if err
                        # failed to download
                        deleteEntry binfolder, (delerr) ->
                            #@TODO handle delerr
                            callback err
                    else
                        @cache.push binfolder
                        callback null, entry.toURL()

    getBinaryFolder: (folder, callback, progressback) ->
        console.log "GBININFOLDER"
        @db.query binariesInFolder(folder), {}, (err, result) =>
            return callback err if err

            sizes = result.rows.map (row) -> row.value.size
            totalSize = sizes.reduce (a,b) -> a + b

            @getFreeDiskSpace (err, available) =>
                console.log "GFDS RESULT = " + available
                return callback err if err
                if totalSize > available
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

        onBinFolderFound = (binfolder) =>
            onSuccess = =>
                # remove from @cache
                for entry, index in @cache when entry.name is binary_id
                    @cache.splice index, 1
                    break

                callback null

            binfolder.removeRecursively onSuccess, callback


        @downloads.getDirectory binary_id, {}, onBinFolderFound, callback

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

deleteEntry = (entry, callback) ->
    onSuccess = -> callback null
    onError = (err) -> callback err
    entry.remove onSuccess, onError

getFile = (parent, name, callback) ->
    onSuccess = (entry) -> callback null, entry
    onError = (err) -> callback err
    parent.getFile name, null, onSuccess, onError

getOrCreateSubFolder = (parent, name, callback) ->
    onSuccess = (entry) -> callback null, entry
    onError = (err) -> callback err
    parent.getDirectory name, {create: true}, onSuccess, onError

getChildren = (directory, callback) ->
    # assume we are using cordova-file-plugin and call reader only once
    reader = directory.createReader()
    onSuccess = (entries) -> callback null, entries
    onError = (err) -> callback err
    reader.readEntries onSuccess, onError

