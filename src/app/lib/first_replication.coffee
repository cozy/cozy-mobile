async = require 'async'
ChangeDispatcher = require '../replicator/change/change_dispatcher'
log = require('./persistent_log')
    prefix: "FirstReplication"
    date: true
instance = null


module.exports = class FirstReplication


    constructor: ->
        return instance if instance
        instance = @

        @replicator = app.init.replicator
        @requestCozy = app.init.requestCozy
        @changeDispatcher = new ChangeDispatcher()
        @config = app.init.config
        @filterManager = app.init.filterManager
        @replicateDb = app.init.database.replicateDb

        @queue = async.queue (task, callback) =>
            @['_' + task] (err) =>
                if err
                    log.warn err
                    return @queue.unshift task, callback
                callback()


    isRunning: ->
        @queue.running() > 0


    getTaskName: ->
        if @isRunning()
            @queue.workersList()[0].data
        else
            ''


    addTask: (task, callback = ->) ->
        @queue.push task, (err) =>
            if err
                status = 'error'
                log.error err
            else
                status = 'success'
                if task is 'files'
                    @config.set 'firstSyncFiles', true
                else if task is 'contacts'
                    @config.set 'firstSyncContacts', true
                else if task is 'calendars'
                    @config.set 'firstSyncCalendars', true

            log.info "task #{task} is finished with #{status}."
            callback()


    addProgressionView: (@updateView) ->


    getRemoteCheckpoint: (callback) ->
        options =
            retry: 3
            method: 'get'
            type: 'replication'
            path: '/_changes?descending=true&limit=1'
        @requestCozy.request options, (err, res, body) ->
            return callback err if err
            callback null, body.last_seq


    getLocalCheckpoint: (callback) ->
        options =
            descending: true
            limit: 1
        @replicateDb.changes options, (err, changes) ->
            return callback err if err
            callback null, changes.last_seq


    _files: (callback) ->
        @getRemoteCheckpoint (err, remoteCheckpoint) =>
            return callback err if err

            @_copyView docType: 'file', (err) =>
                return callback err if err

                @_copyView docType: 'folder', (err) =>
                    return callback err if err

                    @_postCopyViewSync remoteCheckpoint, callback


    _contacts: (callback) ->
        @getRemoteCheckpoint (err, remoteCheckpoint) =>
            return callback err if err

            options =
                docType: 'contact'
                attachments: true
            @_copyView options, (err, contacts) =>
                return callback err if err

                async.eachSeries contacts, (contact, cb) =>
                    @_updateProgression()
                    # 2. dispatch inserted contacts to android
                    @changeDispatcher.dispatch contact, cb
                , (err) =>
                    return callback err if err

                    @_postCopyViewSync remoteCheckpoint, callback


    _calendars: (callback) ->
        @getRemoteCheckpoint (err, remoteCheckpoint) =>
            return callback err if err

            options =
                docType: 'event'
                attachments: true
            @_copyView options, (err, events) =>
                return callback err if err

                async.eachSeries events, (event, cb) =>
                    @_updateProgression()
                    # 2. dispatch inserted contacts to android
                    @changeDispatcher.dispatch event, cb
                , (err) =>
                    return callback err if err

                    @_postCopyViewSync remoteCheckpoint, callback


    _postCopyViewSync: (remoteCheckpoint, callback) ->
        @filterManager.setFilter (err) =>
            return callback err if err

            @getLocalCheckpoint (err, localCheckpoint) =>
                return callback err if err

                options =
                    remoteCheckpoint: remoteCheckpoint
                    localCheckpoint: localCheckpoint
                @replicator.sync options, (err) =>
                    return callback err if err

                    @_updateProgression()
                    @_updateProgression()
                    callback()


    # 1. Fetch all documents of specified docType
    # 2. Put in PouchDB
    # 2.1 : optionnaly, fetch attachments before putting in pouchDB
    # Return the list of added doc to PouchDB.
    _copyView: (options, callback) ->
        log.info "enter copyView for #{options.docType}."

        # Fetch all documents, with a previously put couchdb view.
        fetchAll = (doc, callback) =>
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

                callback err, rows

        # Last step
        putInPouch = (doc, cb) =>
            @replicateDb.put doc, 'new_edits': false, (err) ->
                cb err, doc

        # 1. Fetch all documents
        retryOptions =
            times: options.retry or 1
            interval: 20 * 1000

        async.retry retryOptions, ((cb) -> fetchAll options, cb)
        , (err, rows) =>
            return callback err if err
            return callback null, [] unless rows?.length isnt 0

            @total = rows.length + 1
            @progression = 0
            log.info 'total', @total

            # 2. Put in PouchDB
            async.mapSeries rows, (row, cb) =>
                @_updateProgression()
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


    _updateProgression: ->
        @progression++
        if @updateView
            @updateView @progression, @total
