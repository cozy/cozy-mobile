log = require('../lib/persistent_log')
    prefix: "migration 1.1.1"
    date: true


module.exports =


    migrate: (callback) ->
        config = app.init.config
        cozyUrl = config.get 'cozyURL'

        if cozyUrl[0..6] is 'http://'
            cozyProtocol = 'http://'
        else
            cozyProtocol = 'https://'


        cozyHostname = cozyUrl.replace('http://', '').replace('https://', '')
        cozyUrl = cozyProtocol + cozyHostname

        config.set 'cozyProtocol', cozyProtocol, (err) =>
            log.error err if err
            config.set 'cozyHostname', cozyHostname, (err) =>
                log.error err if err
                config.set 'cozyURL', cozyUrl, (err) =>
                    log.error err if err
                    config.set 'state', 'syncCompleted', callback
