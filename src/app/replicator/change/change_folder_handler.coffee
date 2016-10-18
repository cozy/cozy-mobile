DeletedDocument = require '../../lib/deleted_document'
log = require('../../lib/persistent_log')
    prefix: "ChangeFolderHandler"
    date: true
instance = null


###*
 * ChangeFolderHandler allows to dispatch event when folder change.
 *
 * @class ChangeFolderHandler
###
module.exports = class ChangeFolderHandler


    ###*
     * Create a ChangeFolderHandler.
    ###
    constructor: ->
        return instance if instance
        instance = @

        _.extend @, Backbone.Events
        @deletedDocument = new DeletedDocument()


    ###*
     * When replication change a folder.
     *
     * @param {Object} doc - it's a pouchdb file document.
    ###
    dispatch: (doc, callback) ->
        log.debug "dispatch"

        cb = (err, doc) =>
            @trigger "change:path", @, doc.path if doc?.path or doc?.path is ""
            callback err

        if doc._deleted
            @deletedDocument.getDocBeforeDeleted doc._id, cb
        else
            cb null, doc
