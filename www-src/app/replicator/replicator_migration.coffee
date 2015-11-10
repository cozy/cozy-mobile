log = require('/lib/persistent_log')
    prefix: "replicator_migration_sqlite"
    date: true

DBNAME = "cozy-files.db"
DBPHOTOS = "cozy-photos.db"

module.exports =
    sqliteDB: null
    sqliteDBPhotos: null

    migrateDBs: (callback) ->
        # Check db new db already good.
        @getConfig @db, (err, hasConfig) =>
            return callback err if err
            if hasConfig
                return callback null, 'db already configured'

            # else check old db present.
            @initSQLiteDBs()
            @getConfig @sqliteDB, (err, hasConfig) =>
                return callback err if err
                unless hasConfig
                    return callback null, 'nothing to migrate'

                # else Migrate.
                log.info 'Migrate sqlite db to idb'
                @displayMessage() # Add message to the user
                @replicateDBs (err) =>
                    return callback err if err
                    @destroySQLiteDBs callback


    # Init old sqlite db
    initSQLiteDBs: ->
        @sqliteDBPhotos = new PouchDB DBPHOTOS, adapter: 'websql'
        @sqliteDB = new PouchDB DBNAME, adapter: 'websql'

    getConfig: (db, callback) ->
        db.get 'localconfig', (err, config) =>
            if (err and (err.reason isnt 'missing'))
                return callback err
            else
                return callback null, config?


    replicateDBs: (callback) ->
        replicateDB = (origin, destination, cb) ->
            replication = origin.replicate.to destination
            replication.on 'error', cb
            replication.on 'complete', (report) -> cb null, report

        async.series [
            (cb) => replicateDB @sqliteDBPhotos, @photosDB, cb
            (cb) => replicateDB @sqliteDB, @db, cb
        ], callback

    destroySQLiteDBs: (callback)->
        async.eachSeries [@sqliteDBPhotos, @sqliteDB]
        , (db, cb) =>
            db.destroy cb
        , callback

    displayMessage: ->
        splashMessage = $('<div class="splash-message"></div>')
        splashMessage.text t 'please wait database migration'
        $('body').append splashMessage
