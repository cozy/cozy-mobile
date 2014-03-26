request = require './request'
urlparse = require './url'
DBNAME = "cozy-files"


module.exports = class Replicator

    server: null
    db: null
    config: null

    destroyDB: (callback) ->
        request.couch {url: @db, method:'DELETE'}, callback

    init: (callback) ->
        window.cblite.getURL (err, server) =>
            return callback err if err
            @server = server
            @db = server + DBNAME

            request.get @db, (err, response, body) =>
                if response.statusCode is 404
                    @prepareDatabase callback

                else if response.statusCode is 200
                    @loadConfig callback

                else
                    err ?= new Error('unexpected db state')
                    callback err

    loadConfig: (callback) ->
        request.couch "#{@db}/config", (err, res, config) =>
            if res.statusCode is 404
                callback null, null
            else if res.statusCode is 200
                callback null, @config = config
            else
                err ?= new Error('unexpected config state')
                callback err


    prepareDatabase: (callback) ->
        request.put @db, (err) =>
            return cb err if err

            fullPath = "path.toLowerCase() + '/' + doc.name.toLowerCase()"

            ops = []

            ops.push createView @db, 'Device',
                all:   makeView 'Device', '_id'
                byUrl: makeView 'Device', 'url'

            ops.push createView @db, 'File',
                all:        makeView 'File', '_id'
                byFolder:   makeView 'File', 'path.toLowerCase()'
                byFullPath: makeView 'File', fullPath

            ops.push createView @db, 'Folder',
                all:        makeView 'Folder', '_id'
                byFolder:   makeView 'Folder', 'path.toLowerCase()'
                byFullPath: makeView 'Folder', fullPath

            ops.push createView @db, 'Binary',
                all: makeView 'Device', '_id'

            async.series ops, (err) ->
                callback err

    prepareDevice: (callback) ->
        config = @config
        ops = []
        ops.push (cb) =>
            request.couch
                url: "#{@db}/config"
                method: 'PUT'
                body: config
            , cb

        ops.push (cb) =>
            request.couch
                uri: "#{@db}/_design/#{config.deviceId}"
                method: 'PUT'
                body:
                    views: {}
                    filters:
                        filter:        makeFilter ['Folder', 'File']
                        filterDocType: makeFilter ['Folder', 'File'], true
            , cb

        async.series ops, callback


    registerRemote: (config, callback) ->
        # expect url as "fakename.cozycloud.cc" (no protocol)

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
                callback new Error('ds need patch')
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
                @prepareDevice callback


    replicateToLocalOneShotNoDeleted: (callback) ->
        @start_replication
            source: @config.fullRemoteURL
            target: DBNAME
            filter: "#{@config.deviceId}/filter"
        , callback

    sync: (callback) ->
        @start_replication
            source: @config.fullRemoteURL
            target: DBNAME
            continuous: true
            filter: "#{@config.deviceId}/filterDocType"
        , (err) =>
            return callback err if err
            @start_replication
                source: DBNAME
                target: @config.fullRemoteURL
                continuous: true
                filter: "#{@config.deviceId}/filterDocType"
            , callback

    start_replication: (options, callback) ->
        request.couch
            url: "#{@server}_replicate"
            method: "POST"
            body: options
        , (err, response, replication) =>
            return callback err if err
            return callback null, replication unless options.continuous

            # if the replication is continous, we poll its status
            @status_replication replication._local_id, callback


    cancel_replication: (options, callback) ->
        options.cancel = true
        request.couch
            url: "#{@server}_replicate"
            method: "POST"
            body: options
        , callback

    status_replication: (id, callback) =>
        request.couch
            url: "#{@server}_active_tasks"
            method: "GET"
        , (err, response, tasks) =>
            return callback err if err
            task = _.findWhere tasks, {replication_id: id}

            if not task
                return callback new Error('lost replication')

            if task.error
                return callback task.error[1]

            if task.status in ['Idle', 'Stopped']
                return callback null

            if /Processed/.test(task.status) && !/Processed 0/.test(task.status)
                return callback null

            if /Processed 0 \/ 0 changes/.test(task.status)
                return callback null

            # let's loop
            next = @status_replication.bind(@, id, callback)
            setTimeout next, 1000

createView = (db, docType, views) -> (callback) ->
    request.couch
        uri: "#{db}/_design/#{docType.toLowerCase()}"
        method: 'PUT'
        body: views: views
    , callback

makeView = (docType, field) ->
    fn = (doc) -> emit doc.__field__, doc if doc.docType is '[DOCTYPE]'
    fn = fn.toString().replace('[DOCTYPE]', docType)
    fn = fn.replace('__field__', field)
    return map: fn

makeFilter = (docTypes, allowDeleted) ->
    fn = if allowDeleted then (doc) -> return (doc.docType in docTypes)
    else (doc) -> return not doc._deleted and (doc.docType in docTypes)
    fn = fn.toString().replace('docTypes', JSON.stringify(docTypes))

