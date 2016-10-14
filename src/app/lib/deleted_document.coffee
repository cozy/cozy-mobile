log = require('./persistent_log')
    prefix: "DeletedDocument"
    date: true
instance = null


###*
 * ChangeFileHandler allows to download, rename and delete a file.
 *
 * @class ChangeFileHandler
###
module.exports = class DeletedDocument


    ###*
     * Create a ChangeFileHandler.
    ###
    constructor: ->
        return instance if instance
        instance = @

        @remoteDb = app.init.database.remoteDb


    get: (docId, callback) ->
        options =
            revs: true
            open_revs: 'all'
        @remoteDb.get docId, options, (err, response) =>
            return callback err if err

            if response.length > 0
                doc = response[0].ok
                return callback new Error "" unless doc

                revision = parseInt(doc._rev[0], 10) - 1
                revision += "-" + doc._revisions.ids[1]
                options =
                    rev: revision
                @remoteDb.get docId, options, callback
