async = require "async"
ChangeDispatcher = require "./change/change_dispatcher"
ConflictsHandler = require './change/conflicts_handler'

log = require('../lib/persistent_log')
    prefix: "ReplicationLauncher"
    date: true

###*
 * ReplicationLauncher allows to synchronise Couchdb with pouchdb
 *
 * @class ReplicationLauncher
###
module.exports = class ReplicationLauncher

    @BATCH_SIZE: 20
    @BATCHES_LIMIT: 5
    @realtimeBackupCoef = 1

    ###*
     * Create a ReplicationLauncher.
     *
     * @param {Router} router - it's app router.
    ###
    constructor: (database, @router, @filterName) ->
        @dbLocal = database.replicateDb
        @dbRemote = database.remoteDb
        @changeDispatcher = new ChangeDispatcher()
        @conflictsHandler = new ConflictsHandler database.replicateDb


    ###*
     * Start replicator
     *
     * @param {Object} options - Use live: true to start a live replication.
     *         - use remoteCheckpoint: 12. to set the since option from CouchDB
     *         - use localCheckpoint: 12. to set the since option from PouchDB
               - see _getOptions for more details
     * @param {Function} callback [optionnal]
    ###
    start: (options, callback = ->) ->
        log.debug "start"

        unless @replication
            replicateOptions = @_getOptions options
            log.debug "replicateOptions:", replicateOptions
            @replication = @dbLocal.sync @dbRemote, replicateOptions
            @replication.on 'change', (info) =>
                log.info "replicate change"

                if info.direction is 'pull'
                    # Changes are not trully serialized here, because change
                    # event don't wait for the callback
                    async.eachSeries info.change.docs, (doc, next) =>
                        @conflictsHandler.handleConflicts doc, (err, doc) =>
                            log.error err if err

                            if @router and doc?.docType?.toLowerCase() in \
                                    ['file', 'folder']
                                @router.forceRefresh()

                            if @changeDispatcher.isDispatched doc
                                @changeDispatcher.dispatch doc, next
                            else
                                log.info 'No dispatcher for ', doc?.docType
                                next()
                    , (err) ->
                        log.error err if err

            @replication.on 'paused', (err) ->
                log.info "replicate paused", err
            @replication.on 'active', ->
                log.info "replicate active"
            @replication.on 'denied', (err) ->
                log.info "replicate denied", err
                callback new Error "Replication denied"
            @replication.on 'complete', (info) ->
                log.info "replicate complete"
                callback()
            @replication.on 'error', (err) ->
                log.warn "replicate error", err
                if err.status is 404 and options.remoteCheckpoint
                    return callback()
                callback err


    ###*
     * Stop replicator
    ###
    stop: ->
        log.info "stop"

        @replication.cancel() if @replication
        delete @replication


    ###*
     * Get options for replication
     * @param {Object} options - Use live: true to start a live replication.
     *         - use remoteCheckpoint: 12. to set the since option from CouchDB
     *         - use localCheckpoint: 12. to set the since option from PouchDB
     *
     * @see http://pouchdb.com/api.html#replication
    ###
    _getOptions: (options) ->
        replicationOptions =
            batch_size: ReplicationLauncher.BATCH_SIZE
            batches_limit: ReplicationLauncher.BATCHES_LIMIT
            filter: @filterName

        if options.live
            replicationOptions.live = true
            replicationOptions.retry = true
            replicationOptions.heartbeat = false
            replicationOptions.back_off_function = (delay) ->
                log.info "back_off_function", delay
                return 1000 if delay is 0
                return delay if delay > 60000
                return delay * 2

        if options.localCheckpoint?
            replicationOptions.push = since: options.localCheckpoint

        if options.remoteCheckpoint?
            replicationOptions.pull = since: options.remoteCheckpoint

        return replicationOptions
