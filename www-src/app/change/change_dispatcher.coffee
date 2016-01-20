ChangeFileHandler = require "./change_file_handler"
log = require('../lib/persistent_log')
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

    ###*
     * Create a ChangeDispatcher.
     *
     * @param {ReplicatorConfig} config - it's replication config.
    ###
    constructor: (config) ->
        @changeFileHandler = new ChangeFileHandler config

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

    ###*
     * Check if a doc is authorized to be dispatched
     *
     * @param {Object} doc - it's a pouchdb file document.
     *
     * @return {Boolean}
    ###
    isDispatched: (doc) ->
        return false unless doc.docType
        [@FILE_DOC_TYPE, @FOLDER_DOC_TYPE].indexOf(doc.docType) > -1


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
