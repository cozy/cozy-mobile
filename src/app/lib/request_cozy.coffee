request = require './request'
log = require('./persistent_log')
    prefix: "RequestCozy"
    date: true


# private


get = (options, callback) ->
    request.get options, callback

put = (options, callback) ->
    request.put options, callback

post = (options, callback) ->
    request.post options, callback

del = (options, callback) ->
    request.del options, callback


# public


module.exports = class RequestCozy

    constructor: (@config) ->

    request: (options, callback) ->
        optionsCopy = JSON.parse(JSON.stringify(options))
        delete options.retry
        options.json = true unless options.json

        method = options.method
        delete options.method

        if options.path
            path = options.path
            delete options.path

        unless options.url
            switch options.type
                when 'data-system'
                    options.url = @getDataSystemUrl path
                when 'replication'
                    options.url = "#{@config.get 'cozyURL'}/replication#{path}"
            delete options.type

        unless options.auth
            options.auth =
                username: @config.get 'deviceName'
                password: @config.get 'devicePassword'

        if optionsCopy.retry
            cb = (err) =>
                if err
                    log.debug 'retry'
                    optionsCopy.retry--
                    @request optionsCopy, callback
                else
                    callback.apply @, arguments
        else
            cb = callback

        eval(method)(options, cb)

    getDataSystemUrl: (path, withUrlAuth) ->
        if withUrlAuth
            url = @config.getCozyUrl()
        else
            url = @config.get 'cozyURL'
        "#{url}/ds-api#{path}"

    getDataSystemOption: (path, withUrlAuth) ->
        json: true
        auth:
            username: @config.get 'deviceName'
            password: @config.get 'devicePassword'
        url: @getDataSystemUrl path, withUrlAuth
