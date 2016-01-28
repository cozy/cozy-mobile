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

    # docType
    FILE_DOC_TYPE: "file"
    FOLDER_DOC_TYPE: "folder"
    EVENT_DOC_TYPE: "event"
    CONTACT_DOC_TYPE: "contact"
    TAG_DOC_TYPE: "tag"

    ###*
     * Create a ChangeDispatcher.
     *
     * @param {ReplicatorConfig} config - it's replication config.
    ###
    constructor: (config) ->
        @changeFileHandler = new ChangeFileHandler config
        @changeEventHandler = new ChangeEventHandler()
        @changeContactHandler = new ChangeContactHandler()
        @changeTagHandler = new ChangeTagHandler()

    ###*
     * Launch the good handler with specific state.
     *
     * @param {Object} doc - it's a pouchdb file document.
    ###
    dispatch: (doc) ->
        state = @_getState doc
        log.info "change #{doc.docType}: state is #{state}"

        switch doc.docType
            when @FILE_DOC_TYPE then @changeFileHandler[state] doc
            when @EVENT_DOC_TYPE then @changeEventHandler.dispatch doc
            when @CONTACT_DOC_TYPE then @changeContactHandler[state] doc
            when @TAG_DOC_TYPE then @changeTagHandler[state] doc

    ###*
     * Check if a doc is authorized to be dispatched
     *
     * @param {Object} doc - it's a pouchdb file document.
     *
     * @return {Boolean}
    ###
    isDispatched: (doc) ->
        return false unless doc.docType
        [
            @FILE_DOC_TYPE
            @FOLDER_DOC_TYPE
            @EVENT_DOC_TYPE
            @CONTACT_DOC_TYPE
            @TAG_DOC_TYPE
        ].indexOf(doc.docType) > -1


    ###*
     * Get state of document.
     *
     * @param {Object} doc - it's a pouchdb file document.
     *
     * @return {String}
    ###
    _getState: (doc) ->
        return "delete" if doc._deleted
        return "change"
