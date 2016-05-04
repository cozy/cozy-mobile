log = require('../lib/persistent_log')
    prefix: "migration 1.1.1"
    date: true


module.exports =


    migrate: (callback) ->
        config = app.init.config
        cozyUrl = config.get 'cozyURL'
        config.setCozyUrl cozyUrl, (err) ->
            log.error err if err
            config.set 'state', 'syncCompleted', callback
