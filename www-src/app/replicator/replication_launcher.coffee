ChangeDispatcher = require "./change/change_dispatcher"
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
        @dbFrom = @config.db
        @dbTo = @config.remote
        @filterName = @config.getReplicationFilter()
        @changeDispatcher = new ChangeDispatcher @config


    ###*
     * Start replicator
     *
     * @param {Integer} since - Replicate changes after given sequence number.
     * @param {Boolean} live - Continue replicating after changes.
    ###
    start: (since, live, callback = ->) ->
        log.info "start"

        unless @replication
            @replication = @dbFrom.replicate.from @dbTo, @_getOptions since, live
            @replication.on 'change', (info) =>
                log.info "replicate change"
                for doc in info.docs
                    if @changeDispatcher.isDispatched doc
                        @router.forceRefresh()
                        @changeDispatcher.dispatch doc
            @replication.on 'paused', ->
                log.info "replicate paused"
            @replication.on 'active', ->
                log.info "replicate active"
            @replication.on 'denied', (info) ->
                log.info "replicate denied"
            @replication.on 'complete', (info) =>
                log.info "replicate complete"
                @config.save checkpointed: info.last_seq, ->
                callback()
            @replication.on 'error', (err) ->
                log.info "replicate error"
                log.error err

    ###*
     * Stop replicator
    ###
    stop: ->
        log.info "stop"

        @replication.cancel() if @replication
        delete @replication


    ###*
     * Get options for replication
     *
     * @param {Integer} since - Replicate changes after given sequence number.
     * @param {Boolean} live - Continue replicating after changes.
     *
     * @see http://pouchdb.com/api.html#replication
    ###
    _getOptions: (since, live) ->
        batch_size: @BATCH_SIZE
        batches_limit: @BATCHES_LIMIT
        filter: @filterName
        since: since
        live: live
        retry: true
        back_off_function: (delay) ->
            return 1000 if delay is 0
            return delay if delay > 60000
            return delay * 2
