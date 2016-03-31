request = require 'request-json-light'
log = require("./persistent_log")
    prefix: "Remote"
    date: true

# private

client = null

# public

class Remote

    constructor: (url, username, password) ->
        client = request.newClient url
        client.setBasicAuth username, password

    get: (path, callback) ->
        client.get path, (err, res, body) ->
            callback err, body

    post: (path, data, callback) ->
        client.post path, (err, res, body) ->
            if res?.statusCode isnt 200
                err = err?.message or body.error or body.message
            callback err, body

    put: (path, data, callback) ->
        client.put path, (err, res, body) ->
            callback err, body

    del: (path, callback) ->
        client.del path, (err, res, body) ->
            callback err, body

module.exports = Remote
