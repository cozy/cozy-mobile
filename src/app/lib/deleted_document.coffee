log = require('./persistent_log')
    prefix: "DeletedDocument"
    date: true
instance = null


module.exports = class DeletedDocument


    ###*
     * Create a ChangeFileHandler.
    ###
    constructor: ->
        return instance if instance
        instance = @

        @remoteDb = app.init.database.remoteDb


    getDocBeforeDeleted: (docId, callback) ->
        notFoundError = new Error "Document isn't found."
        getDoc = (docWithRevs, index, callback) =>
            shortRev = parseInt(docWithRevs._rev[0], 10) - index
            return callback notFoundError if shortRev < 1

            revId = docWithRevs._revisions.ids[index]
            revision = "#{shortRev}-#{revId}"
            @remoteDb.get docWithRevs._id, rev: revision, (err, doc) ->
                return callback err if err

                if doc._deleted
                    getDoc docWithRevs, index + 1, callback
                else
                    callback null, doc

        options =
            revs: true
            open_revs: 'all'
        @remoteDb.get docId, options, (err, response) ->
            return callback err if err
            return callback notFoundError unless response.length is 1
            doc = response[0].ok
            return callback notFoundError unless doc

            getDoc doc, 1, callback

