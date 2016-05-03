async = require 'async'


module.exports =


    putRequests: (callback) ->
        requests = require '../replicator/remote_requests'
        config = app.init.config
        requestCozy = app.init.requestCozy
        cozyNotifications = config.get 'cozyNotifications'

        reqList = []
        for docType, reqs of requests
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

        async.eachSeries reqList, (req, cb) ->
            options =
                method: 'put'
                type: 'data-system'
                path: "/request/#{req.type}/#{req.name}/"
                body: req.body
            requestCozy.request options, cb
        , callback
