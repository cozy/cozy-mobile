ChangeManager = require "./../change/change_manager"
log = require('../lib/persistent_log')
    prefix: "Replicator Manager"
    date: true

###*
  * ReplicatorManager allows to synchronise Couchdb with pouchdb
  *
  * @class ReplicatorManager
###
module.exports = class ReplicatorManager

    @BATCH_SIZE: 20
    @BATCHES_LIMIT: 5
    @liveReplication = null
    @realtimeBackupCoef = 1

    ###*
     * Create a ReplicatorManager.
     *
     * @param {ReplicatorConfig} config - it's replication config.
     * @param {Router} router - it's app router.
    ###
    constructor: (@config, @router) ->
        @dbFrom = @config.db
        @dbTo = @config.remote
        @filterName = @config.getReplicationFilter()
        @changeManager = new ChangeManager @config


    ###*
     * Start replicator
     *
     * @param {Integer} since - Replicate changes after given sequence number.
     * @param {Boolean} live - Continue replicating after changes.
    ###
    start: (since, live) ->
        log.info "start"

        @liveReplication =
            @dbFrom.replicate.from @dbTo, @_getOptions(since, live)
        @liveReplication.on 'change', (info) =>
            console.log "replicate change"
            console.log info
            for doc in info.docs
                if doc.docType in ["folder", "file"]
                    @router.forceRefresh()
                    @config.save checkpointed: info.last_seq, ->
                @changeManager.change doc
        @liveReplication.on 'paused', ->
            console.log "replicate paused"
        @liveReplication.on 'active', ->
            console.log "replicate active"
        @liveReplication.on 'denied', (info) ->
            console.log "replicate denied"
            console.log JSON.stringify info
        @liveReplication.on 'complete', (info) ->
            console.log "replicate complete"
            console.log JSON.stringify info
        @liveReplication.on 'error', (err) ->
            console.log "replicate error"
            console.log err

    ###*
     * Stop replicator
    ###
    stop: ->
        log.info "stop"

        if @liveReplication
            @liveReplication.off()
            @liveReplication.cancel()


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
            return delay if delay > 5000
            return delay * 2
