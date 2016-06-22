async = require 'async'
log = require('../lib/persistent_log')
    prefix: "putRemoteRequest"
    date: true


module.exports =


    putRequests: (callback, reqError = [], retry = 0) ->
        requests = require '../replicator/remote_requests'
        config = app.init.config
        requestCozy = app.init.requestCozy
        cozyNotifications = config.get 'cozyNotifications'

        reqList = []
        for docType, reqs of requests when reqError.length is 0
            if docType is 'file' or docType is 'folder' or \
                    (docType is 'contact' and config.get 'syncContacts') or \
                    (docType is 'contact' and config.get 'syncContacts') or \
                    (docType is 'event' and config.get 'syncCalendars') or \
                    (docType is 'notification' and cozyNotifications)\
                    or (docType is 'tag' and config.get 'syncCalendars')

                for reqName, body of reqs

                    reqList.push
                        type: docType
                        name: reqName
                        # Copy/Past from cozydb, to avoid view multiplication
                        # TODO: reduce is not supported yet
                        body: map: """
                        function (doc) {
                          if (doc.docType.toLowerCase() === "#{docType}") {
                            filter = #{body.toString()};
                            filter(doc);
                          }
                        }
                    """

        if reqError.length > 0
            reqList = reqError
            reqError = []

        async.eachSeries reqList, (req, cb) ->
            options =
                method: 'put'
                type: 'data-system'
                path: "/request/#{req.type}/#{req.name}/"
                body: req.body
                retry: 3
            requestCozy.request options, (err) ->
                if err
                    log.warn "download failed with #{req.type}."
                    reqError.push req
                cb()
        , =>
            if reqError.length > 0 and retry < 3
                log.debug 'retry'
                return @putRequests callback, reqError, retry++
            else if reqError.length is 1
                callback reqError[0]
            else if reqError.length > 0
                for error in reqError
                    log.error error
                error = new Error 'error_multiple_import'
                error.errors = reqError
                callback error
            else
                callback()
