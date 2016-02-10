ChangeFileHandler = require "./change_file_handler"
ChangeEventHandler = require "./change_event_handler"
ChangeContactHandler = require "./change_contact_handler"
ChangeTagHandler = require "./change_tag_handler"
log = require('../../lib/persistent_log')
    prefix: "ChangeDispatcher"
    date: true

###*
 * ChangeDispatcher allows to launch the good manager with specific state
 *
 * @class ChangeDispatcher
###
module.exports = class ChangeDispatcher


    ###*
     * Create a ChangeDispatcher.
     *
     * @param {ReplicatorConfig} config - it's replication config.
    ###
    constructor: (config) ->
        @changeHandlers =
            "folder": false
            "file": new ChangeFileHandler config
            "event": new ChangeEventHandler()
            "contact": new ChangeContactHandler()
            "tag": new ChangeTagHandler()


    ###*
     * Launch the good handler with specific state.
     *
     * @param {Object} doc - it's a pouchdb file document.
    ###
    dispatch: (doc, callback = ->) ->
        log.info "dispatch #{doc.docType}"

        if @isDispatched(doc) and @changeHandlers[doc.docType]
            @changeHandlers[doc.docType]["dispatch"] doc, callback

    ###*
     * Check if a doc is authorized to be dispatched
     *
     * @param {Object} doc - it's a pouchdb file document.
     *
     * @return {Boolean}
    ###
    isDispatched: (doc) ->
        return doc?.docType?.toLowerCase() of @changeHandlers
