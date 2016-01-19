FileManager = require "./file_manager"
log = require('../lib/persistent_log')
    prefix: "Change Manager"
    date: true

###*
 * ChangeManager allows to launch the good manager with specific state
 *
 * @class ChangeManager
###
module.exports = class ChangeManager

    ###*
     * Create a FilterManager.
     *
     * @param {ReplicatorConfig} config - it's replication config.
    ###
    constructor: (config) ->
        @fileManager = new FileManager config

    ###*
     * Launch the good manager with specific state.
     *
     * @param {Object} doc - it's a pouchdb file document.
    ###
    change: (doc) ->
        state = @_getState doc
        log.info "change #{doc.docType}: #{state}"

        switch doc.docType
            when "file" then @fileManager[state] doc


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
