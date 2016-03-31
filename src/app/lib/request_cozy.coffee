request = require './request'


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


class RequestCozy

    constructor: (@config) ->

    request: (options, callback) ->
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

        eval(method)(options, callback)

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

module.exports = RequestCozy
