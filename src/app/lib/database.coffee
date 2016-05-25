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
    #   'idb': actual database
    #   'websql': old database
    #
    # To test:
    #   options = db: require 'memdown'
    constructor: (options = adapter: 'idb', cache: false) ->
        log.debug 'constructor', options

        if device.platform is "Android"
            # device.version is not a semantic version:
            #   - Froyo OS would return "2.2"
            #   - Eclair OS would return "2.1", "2.0.1", or "2.0"
            #   - Version can also return update level "2.1-update1"
            version = device.version.split('-')[0]
            version += '.0' unless semver.valid version

            # https://pouchdb.com/adapters.html
            if not semver.valid(version) or semver.lt version, '4.4.0'
                log.info 'Require websql'
                log.debug device.version, version
                options = adapter: 'websql'

        @replicateDb = new PouchDB Database.REPLICATE_DB, options
        @localDb = new PouchDB Database.LOCAL_DB, options

    setRemoteDatabase: (cozyUrl) ->
        log.debug "setRemoteDatabase"

        @remoteDb = new PouchDB "#{cozyUrl}/replication"

    destroy: ->
        log.debug "destroy"

        @replicateDb.destroy()
        @localDb.destroy()

module.exports = Database
