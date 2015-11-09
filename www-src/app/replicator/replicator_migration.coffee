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
            return callback err if err and err.reason isnt 'missing'
            return callback null, 'db already configured' if hasConfig

            # else check old db present.
            @initSQLiteDBs()
            @getConfig @sqliteDB, (err, hasConfig) =>
                return callback err if err and err.reason isnt 'missing'
                return callback null, 'nothing to migrate' unless hasConfig

                log.info 'Migrate sqlite db to idb'
                # else Migrate.
                @replicateDBs (err) =>
                    return callback err if err
                    # TODO
                    destroySQLiteDBs callback


    # Init old sqlite db
    initSQLiteDBs: ->
        @sqliteDBPhotos = new PouchDB DBPHOTOS, adapter: 'websql'
        @sqliteDB = new PouchDB DBNAME, adapter: 'websql'

    getConfig: (db, callback) ->
        db.get 'localconfig', (err, config) =>
            return callback err if err
            return callback null, config?


    replicateDBs: (callback) ->
        replicateDB = (origin, destination, callback) ->
            replication = origin.replicate.to destination
            replication.on 'error', callback
            replication.on 'complete', (repport) -> callback null, report

        async.series [
            (cb) => replicateDB @sqliteDBPhotos, @photosDB, cb
            (cb) => replicateDB @sqliteDB, @db, cb
        ], callback

    destroySQLiteDBs: (callback)->
        async.eachSeries [@sqliteDBPhotos, @sqliteDB]
        , (db, cb) => db.remove cb
        , callback
