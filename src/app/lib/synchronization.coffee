async = require 'async'
ChangesImporter = require '../replicator/fromDevice/changes_importer'
ConnectionHandler = require './connection_handler'
MediaUploader = require './media/media_uploader'
FirstReplication = require './first_replication'
log = require('./persistent_log')
    prefix: "Synchronization"
    date: true
instance = null


module.exports = class Synchronization


    constructor: ->
        return instance if instance
        instance = @

        @filterManager = app.init.filterManager
        @replicator = app.init.replicator
        @config = app.init.config
        @changesImporter = new ChangesImporter()
        @mediaUploader = new MediaUploader()
        @connectionHandler = new ConnectionHandler()
        @firstReplication = new FirstReplication @

        @currentSynchro = false
        @live = false


    sync: (@syncLoop = true, callback = ->) ->
        unless @currentSynchro
            log.info 'start synchronization'
            @currentSynchro = true

            @checkFilter (err) =>
                return @_finishSync err, callback if err

                @checkFirstReplication (err) =>
                    return @_finishSync err, callback if err

                    @syncCozyToAndroid live: false, (err) =>
                        return @_finishSync err, callback if err

                        @syncAndroidToCozy (err) =>
                            return @_finishSync err, callback if err

                            @syncCozyToAndroid live: true, (err) ->
                                # don't finishSync may be is already call
                                # synchronization live restart with next sync
                                log.warn err if err

                            @uploadMedia (err) =>
                                return @_finishSync err, callback if err

                                @downloadCacheFile (err) =>
                                    @_finishSync err, callback


    _finishSync: (err, callback) ->
        @currentSynchro = false
        if err
            log.warn err
        log.info 'end synchronization'

        if @syncLoop
            setTimeout =>
                @sync @syncLoop, callback
            , 60 * 1000
        else
            callback()


    checkFilter: (callback) ->
        @_canSync (err) =>
            return callback err if err

            @filterManager.filterLocalIsSame (isSame) =>
                unless isSame
                    @stop()
                    return @filterManager.setFilter callback

                @filterManager.filterRemoteIsSame (isSame) =>
                    if isSame
                        callback()
                    else
                        @stop()
                        @filterManager.setFilter callback


    checkFirstReplication: (callback) ->
        @_canSync (err) =>
            return callback err if err
            return callback() if @config.firstSyncIsDone()

            checkFiles = (callback) =>
                if @config.get 'firstSyncFiles'
                    callback()
                else
                    @firstReplication.addTask 'files', callback

            checkContacts = (callback) =>
                if @config.get('syncContacts') and \
                        not @config.get('firstSyncContacts')
                    @firstReplication.addTask 'contacts', callback
                else
                    callback()

            checkCalendars = (callback) =>
                if @config.get('syncCalendars') and \
                        not @config.get('firstSyncCalendars')
                    @firstReplication.addTask 'calendars', callback
                else
                    callback()

            checkFiles ->
                checkContacts ->
                    checkCalendars ->
                        callback()


    syncCozyToAndroid: (options, callback) ->
        @_canSync (err) =>
            return callback err if err
            return callback() if @live

            log.info 'start synchronization cozy to android'
            @live = true if options.live
            @replicator.startRealtime options, (err) =>
                @live = false if options.live
                callback err


    syncAndroidToCozy: (callback) ->
        @_canSync (err) =>
            return callback err if err

            log.info 'start synchronization android to cozy'
            @changesImporter.synchronize callback


    uploadMedia: (callback) ->
        @_canSync (err) =>
            return callback err if err

            if config.get 'firstSyncFiles'
                log.info 'start upload media'
                @mediaUploader.upload callback
            else
                callback()


    downloadCacheFile: (callback) ->
        @_canSync (err) =>
            return callback err if err

            log.info 'start download cache file'
            @replicator.syncCache callback


    _canSync: (callback)->
        isConnected = @connectionHandler.isConnected()
        isStateOk = 'appConfigured' is @config.get 'state'
        syncIsFinish = not @firstReplication.isRunning()
        if isConnected and isStateOk and syncIsFinish
            callback()
        else
            callback "can't synchronize"


    stop: ->
        if @live
            @live = false
            @replicator.stopRealtime()
