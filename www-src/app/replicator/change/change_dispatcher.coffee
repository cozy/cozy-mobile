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
        log.info "change #{doc.docType}"
        if doc.docType is "file"
            state = @_getState doc
            @changeHandlers.file[state] doc

        handler = @changeHandlers[doc.docType]
        if handler?
            handler.dispatch doc, callback

    ###*
     * Check if a doc is authorized to be dispatched
     *
     * @param {Object} doc - it's a pouchdb file document.
     *
     * @return {Boolean}
    ###
    isDispatched: (doc) ->
        return doc.docType of @changeHandlers

    ###*
     * @deprecated : move  handler to 'dispatch' API
     * Get state of document.
     *
     * @param {Object} doc - it's a pouchdb file document.
     *
     * @return {String}
    ###
    _getState: (doc) ->
        return "delete" if doc._deleted
        return "change"
