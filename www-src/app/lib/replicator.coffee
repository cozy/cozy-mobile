request = require './request'
basic = require './basic'
DBNAME = "cozy-files"

REGEXP_PROCESS_STATUS = /Processed (\d+) \/ (\d+) changes/

module.exports = class Replicator

    server: null
    db: null
    config: null

    destroyDB: (callback) ->
        @db.destroy callback

    init: (callback) ->
        @initDownloadFolder (err) =>
            return callback err if err
            @db = new PouchDB DBNAME #, adapter: 'websql'
            @db.get 'localconfig', (err, config) =>
                if err
                    console.log err
                    callback null, null
                else
                    @config = config
                    callback null, config


    initDownloadFolder: (callback) ->
        if window.isBrowserDebugging # flag for developpement in browser
            @cache = []
            return callback null

        onError = (err) -> callback err
        onSuccess = (fs) =>
            getOrCreateSubFolder fs.root, 'cozy-downloads', (err, downloads) =>
                return callback err if err
                @downloads = downloads
                getChildren downloads, (err, children) =>
                    return callback err if err
                    @cache = children
                    callback null

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
        @db.replicate.from @config.fullRemoteURL,
            filter: "#{@config.deviceId}/filterDocType"
            complete: (err, result) =>
                return callback err if err
                @config.checkpointed = result.last_seq
                @saveConfig callback

    download: (binary_id, local, callback) ->
        url = encodeURI "#{@config.fullRemoteURL}/#{binary_id}/file"
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
        ft.download url, local, onSuccess, onError, false, options

    getBinary: (model, callback) ->
        binary_id = model.binary.file.id

        getOrCreateSubFolder @downloads, binary_id, (err, binfolder) =>
            return callback err if err

            getFile binfolder, model.name, (err, entry) =>
                return callback null, entry.toURL() if entry

                # getFile failed, let's download
                local = binfolder.toURL() + '/' + model.name
                @download binary_id, local, (err, entry) =>
                    if err
                        # failed to download
                        deleteEntry binfolder, (delerr) ->
                            #@TODO handle delerr
                            callback err
                    else
                        @cache.push binfolder
                        callback null, entry.toURL()

    sync: (callback) ->
        @db.replicate.from @config.fullRemoteURL,
            filter: "#{@config.deviceId}/filter"
            since: @config.checkpointed
            complete: (err, result) =>
                @config.checkpointed = result.last_seq
                @saveConfig callback


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

