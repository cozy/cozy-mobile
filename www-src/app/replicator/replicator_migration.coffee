async = require 'async'
log = require('../lib/persistent_log')
    prefix: "replicator_migration_sqlite"
    date: true

DBNAME = "cozy-files.db"
DBPHOTOS = "cozy-photos.db"

module.exports =
    sqliteDB: null
    sqliteDBPhotos: null


    migrateDBs: (callback) ->
        # Check db new db already good.
        @db.get '_local/appconfig', (err, config) =>
            return callback err if (err and (err.status isnt 404))
            return callback null, 'db already configured' if config?

            # else check old db present.
            @initSQLiteDBs()
            @sqliteDB.get 'localconfig', (err, config) =>
                return callback err if (err and (err.status isnt 404))
                return callback null, 'nothing to migrate' unless config?

                # else Migrate.
                log.info 'Migrate sqlite db to idb'
                @displayMessage() # Add message to the user
                @replicateDBs (err) =>
                    return callback err if err
                    @destroySQLiteDBs callback

    migrateConfig: (callback) ->
        @db.get '_local/appconfig', (err, config) =>
            return callback err if (err and (err.status isnt 404))
            return callback null, 'config already migrated' if config?

            # else
            @moveConfig callback

    # Init old sqlite db
    initSQLiteDBs: ->
        @sqliteDBPhotos = new PouchDB DBPHOTOS, adapter: 'websql'
        @sqliteDB = new PouchDB DBNAME, adapter: 'websql'


    replicateDBs: (callback) ->
        replicateDB = (origin, destination, cb) ->
            replication = origin.replicate.to destination
            replication.on 'error', cb
            replication.on 'complete', (report) -> cb null, report

        async.series [
            (cb) => replicateDB @sqliteDBPhotos, @photosDB, cb
            (cb) => replicateDB @sqliteDB, @db, cb
            (cb) => @moveConfig cb

        ], callback


    moveConfig: (callback) ->
        @db.get 'localconfig', (err, config) =>
            if err
                if err.status is 404
                    log.info 'no config to move.'
                    return callback()
                else
                    return callback err

            return callback err if err
            # Keep id and rev for further deletion
            id = config._id
            rev = config._rev

            # Update for new config.
            config._id = '_local/appconfig'
            delete config._rev
            @db.put config, (err, newConfig) =>
                return callback err if err
                @db.remove id, rev, callback


    destroySQLiteDBs: (callback)->
        async.eachSeries [@sqliteDBPhotos, @sqliteDB]
        , (db, cb) ->
            db.destroy cb
        , callback


    displayMessage: ->
        splashMessage = $('<div class="splash-message"></div>')
        splashMessage.text t 'please wait database migration'
        $('body').append splashMessage
