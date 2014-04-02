request = require './request'
urlparse = require './url'
DBNAME = "cozy-files"

REGEXP_PROCESS_STATUS = /Processed (\d+) \/ (\d+) changes/

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
                all: makeView 'Binary', '_id'

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
                        filter:        makeFilter ['Folder', 'File'], true
                        filterDocType: makeFilter ['Folder', 'File']
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


    initialReplication: (progressback, callback) ->

        expectedtotal = 3000
        done = 0

        # begin the replication
        xhr = @start_replication
            source: @config.fullRemoteURL
            target: DBNAME
            filter: "#{@config.deviceId}/filterDocType"
        , (err, replication) =>
            waiting = @waitReplication replication, {}, (err) ->
                callback err

        return abort: ->
            waiting.abort() if waiting
            xhr?.abort()


    getBinary: (binary, callback) ->
        binary_id = binary.file.id
        binary_rev = binary.file.rev
        url = "#{@db}/#{binary_id}/file"
        waiting = null

        xhr = request.couch {url, method: 'HEAD'}, (err, response) =>

            return callback null, url if response.statusCode isnt 404

            xhr = @start_replication
                source: @config.fullRemoteURL
                target: DBNAME
                since: 0
                filter: '_doc_ids'
                doc_ids: "%5B%22#{binary_id}%22%5D"
            , (err, replication) =>
                xhr = null
                return callback err if err
                waiting = @waitReplication replication, (err) =>
                    callback err, url


        return abort: ->
            waiting.abort() if waiting
            xhr?.abort()

    startSync: (callback) ->
        @start_replication
            source: @config.fullRemoteURL
            target: DBNAME
            continuous: true
            filter: "#{@config.deviceId}/filter"
        , (err) =>
            return callback err if err
            @start_replication
                source: DBNAME
                target: @config.fullRemoteURL
                continuous: true
                filter: "#{@config.deviceId}/filter"
            , callback

    stopSync: (callback) ->
        @cancel_replication
            source: DBNAME
            target: @config.fullRemoteURL
        , (err) =>
            @cancel_replication
                source: @config.fullRemoteURL
                target: DBNAME
            , callback

    start_replication: (options, callback) ->
        request.couch
            url: "#{@server}_replicate"
            method: "POST"
            body: options
        , (err, response, replication) =>
            callback err, replication

    cancel_replication: (options, callback) ->
        {source, target} = options
        request.couch
            url: "#{@server}_replicate"
            method: "POST"
            body: {source, target, cancel: true}
        , (err, response, body) ->
            # if we can't find the replication, that's a good thing
            err = null if err.message.indexOf('unable to lookup') is -1
            callback err


    replication_status: (replication, callback) ->
        request.couch "#{@server}_active_tasks", (err, response, tasks) =>
            return callback err if err
            # couch vs couchbase lite
            id = replication._local_id or replication.session_id
            task = _.findWhere(tasks, {replication_id: id}) or
                   _.findWhere(tasks, {task: id})

            console.log JSON.stringify(task)

            if not task
                return callback null, null

            if task.error
                return callback task.error[1] or task.error[0]

            if task.status in ['Idle', 'Stopped']
                # Not quite sure when we get here. iOS ?
                task.complete = true

            else if REGEXP_PROCESS_STATUS.test task.status
                [all, done, total] = REGEXP_PROCESS_STATUS.exec task.status
                task.done = parseInt done
                task.total = parseInt total

            return callback null, task

    waitReplication: (replication, waiting, callback) ->

        waiting.xhr = @replication_status replication, (err, task) =>
            waiting.xhr = null

            return callback err if err
            return callback null if not task or task.complete

            # normal for a continous to get stuck
            return callback null if replication.continuous

            if waiting.lastDone isnt task.done
                waiting.lastDone = task.done
                waiting.bugCount = if task.done > 0 then 10 else 0
            else if ++waiting.bugCount > 12
                # status hasnt changed for 2 minutes
                # either the replication failed or it succeeds
                # let's abort it
                return @cancel_replication task, (err) ->
                    console.log err if err
                    callback null

            next = @waitReplication.bind(@, replication, waiting, callback)
            waiting.timer = setTimeout next, 10000

        return abort: ->
            waiting.xhr?.abort()
            clearTimeout waiting.timer if waiting.timer




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

    test = ("doc.docType == '#{docType}'" for docType in docTypes).join(' || ')

    fn = if allowDeleted then (doc) -> return doc._deleted or test
    else (doc) -> return test

    fn = fn.toString().replace 'test', test

