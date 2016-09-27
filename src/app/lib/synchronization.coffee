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
                            if syncLoop
                                setTimeout =>
                                    @sync()
                                , 3 * 60 * 1000
                            else
                                callback()


    syncCozyToAndroid: (options, callback) ->
        callback() unless @connectionHandler.isConnected()
        @canSync (err, isOk) =>
            log.warn err if err

            if isOk and not @live
                @live = true if options.live
                @replicator.startRealtime options, (err) =>
                    @live = false if options.live
                    callback err
            else
                callback()


    syncAndroidToCozy: (callback) ->
        callback() unless @connectionHandler.isConnected()
        @canSync (err, isOk) =>
            log.warn err if err

            if isOk
                @changesImporter.synchronize callback
            else
                callback()


    uploadMedia: (callback) ->
        @mediaUploader.upload callback


    downloadCacheFile: (callback) ->
        @replicator.syncCache callback


    canSync: (callback)->
        if 'syncCompleted' is @config.get 'state'
            @filterManader.setFilter callback


    stop: ->
        @replicator.stopRealtime()
