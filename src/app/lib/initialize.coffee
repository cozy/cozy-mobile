async = require 'async'
AndroidAccount = require '../replicator/fromDevice/android_account'
ChangeDispatcher = require '../replicator/change/change_dispatcher'
ChangesImporter = require '../replicator/fromDevice/changes_importer'
CheckPlatformVersions = require '../migrations/check_platform_versions'
Config = require './config'
Database = require './database'
DesignDocuments = require '../replicator/design_documents'
DeviceStatus   = require './device_status'
FilterManager = require '../replicator/filter_manager'
FileCacheHandler = require './file_cache_handler'
PutRemoteRequest = require('../migrations/put_remote_request')
Replicator = require '../replicator/main'
RequestCozy = require './request_cozy'
Translation = require './translation'
ConnectionHandler = require './connection_handler'
toast = require './toast'
AndroidAccount = require '../replicator/fromDevice/android_account'


log = require('./persistent_log')
    prefix: "Initialize"
    date: true

module.exports = class Initialize

    _.extend Initialize.prototype, Backbone.Events

    constructor: (@app) ->
        log.debug "constructor"

        @connection = new ConnectionHandler()
        @translation = new Translation()
        @database = new Database()
        @config = new Config @database
        @replicator = new Replicator()
        @requestCozy = new RequestCozy @config
        @fileCacheHandler = new FileCacheHandler @database.localDb, \
          @database.replicateDb, @requestCozy
        androidAccount = new AndroidAccount()
        androidAccount.create (err) ->
            log.info err if err
        @


    initConfig: (callback) ->
        DeviceStatus.initialize()

        @translation.setDeviceLocale =>
            @config.load =>
                state = if @app.name is 'APP' then 'launch' else 'service'
                @config.set 'appState', state, =>
                    @fileCacheHandler.load =>
                        @replicator.initConfig @config, @requestCozy, @database, \
                            @fileCacheHandler
                        @replicator.initFileSystem =>
                            callback()




    upsertLocalDesignDocuments: (callback) ->
        designDocs =
            new DesignDocuments @database.replicateDb, @database.localDb
        unless callback
            callback = ->
        designDocs.createOrUpdateAllDesign callback