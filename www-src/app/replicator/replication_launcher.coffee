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
     * @param {ReplicatorConfig} config - it's replication config.
     * @param {Router} router - it's app router.
    ###
    constructor: (@config, @router) ->
        @dbLocal = @config.db
        @dbRemote = @config.remote
        @filterName = @config.getReplicationFilter()
        @changeDispatcher = new ChangeDispatcher @config
        @conflictsHandler = new ConflictsHandler @config.db


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
        log.info "start"

        unless @replication
            @replication = @dbLocal.sync @dbRemote, @_getOptions options
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
                                log.warn 'unwanted doc !', doc.docType
                                next()

            @replication.on 'paused', ->
                log.info "replicate paused"
            @replication.on 'active', ->
                log.info "replicate active"
            @replication.on 'denied', (info) ->
                log.info "replicate denied", info
                callback new Error "Replication denied"
            @replication.on 'complete', (info) ->
                log.info "replicate complete", info
                callback()
            @replication.on 'error', (err) ->
                log.error "replicate error", err
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
