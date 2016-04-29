FilterManager = require '../replicator/filter_manager'


module.exports =


    migrate: (callback) ->
        config = app.init.config
        if config.get 'cozyNotifications'
            db = app.init.database.replicateDb
            requestCozy = app.init.requestCozy
            filterManager = new FilterManager config, requestCozy, db
            filterManager.setFilter callback
        else
            callback()
