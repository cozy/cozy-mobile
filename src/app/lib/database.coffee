PouchDB = require 'pouchdb'
semver = require 'semver'
log = require("./persistent_log")
    prefix: "Database"
    date: true


class Database


    @REPLICATE_DB: 'cozy-files.db'
    @LOCAL_DB: 'cozy-photos.db'


    # Create databases
    #
    # adapter:
    #   'websql': for iOS and Android < 4.4.0
    #   'idb': for Android >= 4.4.0
    #
    # To test:
    #   options = db: require 'memdown'
    constructor: (options) ->
        options ?= _getOptions()
        @replicateDb = new PouchDB Database.REPLICATE_DB, options
        @localDb = new PouchDB Database.LOCAL_DB, options


    setRemoteDatabase: (cozyUrl) ->
        log.debug "setRemoteDatabase"

        @remoteDb = new PouchDB "#{cozyUrl}/replication"


module.exports = Database


_getOptions = ->
    options =
        adapter: 'websql'
        location: 'default'
        auto_compaction: true


    if device.platform is "Android"
        # device.version is not a semantic version:
        #   - Froyo OS would return "2.2"
        #   - Eclair OS would return "2.1", "2.0.1", or "2.0"
        #   - Version can also return update level "2.1-update1"
        version = device.version.split('-')[0]
        version += '.0' unless semver.valid version

        # https://pouchdb.com/adapters.html
        log.debug "Android version:", device.version, version
        if semver.valid(version) and semver.gte version, '4.4.0'
            log.info 'Require idb'
            options.adapter = 'idb'

    return options
