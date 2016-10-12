async = require 'async'
log = require('./persistent_log')
    prefix: "RemoteRequest"
    date: true
instance = null


all = (doc) -> emit doc._id, doc._id
config =
    file: all: all
    folder:
        all: all
        byFullPath: (doc) -> emit (doc.path + '/' + doc.name), doc._id
    contact: all: all
    event: all: all
    tag: byname: (doc) -> emit doc.name, doc._id
    notification: all: all



module.exports = class RemoteRequest


    constructor: (@requestCozy) ->
        return instance if instance
        instance = @

        @requestCozy ?= app.init.requestCozy


    putRequest: (docType, filterName, callback) ->
        options =
            method: 'put'
            type: 'data-system'
            path: "/request/#{docType}/#{filterName}/"
            body:
                map: """
                    function (doc) {
                      if (doc.docType.toLowerCase() === "#{docType}") {
                        filter = #{config[docType][filterName].toString()};
                        filter(doc);
                      }
                    }
                """
            retry: 3
        @requestCozy.request options, callback


    fetchAll: (doc, callback) ->
        @putRequest doc.docType, 'all', (err) =>
            return log.error err if err

            options =
                method: 'post'
                type: 'data-system'
                path: "/request/#{doc.docType}/all/"
                body:
                    include_docs: true
                    show_revs: true
                retry: doc.retry
            @requestCozy.request options, (err, res, rows) ->
                if not err and res.statusCode isnt 200
                    err = new Error res.statusCode, res.reason

                callback err, rows
