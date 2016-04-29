module.exports =


    migrate: (callback) ->
        config = app.init.config
        defaultConfig = config.getDefault()
        replicateDb = app.init.database.replicateDb
        newConfig = {}

        replicateDb.get defaultConfig._id, (err, doc) ->
            return callback err if err

            # remove auth
            # remove lastInitState
            # add state
            for key of defaultConfig
                if doc[key] isnt undefined
                    newConfig[key] = doc[key]
                else
                    newConfig[key] = defaultConfig[key]

            newConfig._rev = doc._rev
            if doc.lastBackup > 0 or doc.lastSync > 0
                newConfig.state = 'syncCompleted'

            config.setConfigValue newConfig
            db.put newConfig, (err) =>
                return callback err if err
                @setCozyUrl @get('cozyURL'), callback
