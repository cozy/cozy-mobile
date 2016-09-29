async = require 'async'
ChangesImporter = require '../replicator/fromDevice/changes_importer'
ConnectionHandler = require './connection_handler'
FilterManager = require '../replicator/filter_manager'
MediaUploader = require './media/media_uploader'
log = require('./persistent_log')
    prefix: "Synchronization"
    date: true
instance = null


module.exports = class Synchronization


    constructor: ->
        return instance if instance
        instance = @

        @filterManader = new FilterManager()
        @replicator = app.init.replicator
        @config = app.init.config
        @changesImporter = new ChangesImporter()
        @mediaUploader = new MediaUploader()
        @connectionHandler = new ConnectionHandler()

        @currentSynchro = false
        @live = false
        @sync()


    sync: (syncLoop = true, callback = ->) ->
        unless @currentSynchro
            log.info 'start synchronization'
            @currentSynchro = true
            @syncCozyToAndroid live: false, (err) =>
                log.warn err if err

                @syncAndroidToCozy (err) =>
                    log.warn err if err

                    @syncCozyToAndroid live: true, (err) =>
                        log.warn err if err

                    @uploadMedia (err) =>
                        log.warn err if err

                        @downloadCacheFile (err) =>
                            log.warn err if err

                            @currentSynchro = false
                            log.info 'end synchronization'
                            if syncLoop
                                setTimeout =>
                                    @sync()
                                , 60 * 1000
                            else
                                callback()


    syncCozyToAndroid: (options, callback) ->
        @canSync (err, isOk) =>
            log.warn err if err

            if isOk and not @live
                log.info 'start synchronization cozy to android'
                @live = true if options.live
                @replicator.startRealtime options, (err) =>
                    @live = false if options.live
                    callback err
            else
                callback()


    syncAndroidToCozy: (callback) ->
        @canSync (err, isOk) =>
            log.warn err if err

            if isOk
                log.info 'start synchronization android to cozy'
                @changesImporter.synchronize callback
            else
                callback()


    uploadMedia: (callback) ->
        @canSync (err, isOk) =>
            log.warn err if err

            if isOk
                log.info 'start upload media'
                @mediaUploader.upload callback
            else
                callback()


    downloadCacheFile: (callback) ->
        @canSync (err, isOk) =>
            log.warn err if err

            if isOk
                log.info 'start download cache file'
                @replicator.syncCache callback
            else
                callback()


    canSync: (callback)->
        isConnected = @connectionHandler.isConnected()
        isStateOk = 'syncCompleted' is @config.get 'state'
        if isConnected and isStateOk
            @filterManader.filterRemoteExist callback
        else
            callback null, false


    stop: ->
        @replicator.stopRealtime()
