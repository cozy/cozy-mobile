module.exports =


    migrate: (callback) ->
        config = app.init.config
        defaultConfig = config.getDefault()
        newConfig = {}

        replicateDb.get defaultConfig._id, (err, doc) ->
            return callback err if err

            # remove auth
            # remove lastInitState
            # add state
            for key of defaultConfig
                if key of doc
                    newConfig[key] = doc[key]
                else
                    newConfig[key] = defaultConfig[key]

            if newConfig.state is 'syncCompleted'
                newConfig.state = 'appConfigured'

            newConfig._rev = doc._rev

            config.setConfigValue newConfig
            replicateDb.put newConfig, callback
