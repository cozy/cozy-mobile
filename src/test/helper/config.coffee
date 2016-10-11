Config = require '../../app/lib/config'


module.exports =


    url: 'https://test.cozycloud.cc'


    get: (database) ->
        initialize =
            upsertLocalDesignDocuments: (callback) ->
                callback()
        new Config database, initialize


    getLoaded: (database, callback) ->
        config = @get database
        config.load ->
            callback config


    getLoadedWithUrl: (database, callback) ->
        @getLoaded database, (config) =>
            config.setCozyUrl @url, ->
                callback config
