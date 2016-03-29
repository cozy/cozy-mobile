log = require('../lib/persistent_log')
    prefix: "Filter Manager"
    date: true
request = require '../lib/request'

###*
 * FilterManager allows to create a filter specific by device and
 * get this filter to replicate couchdb with it to reduce consumption data.
 *
 * @class FilterManager
 * @see https://git.io/vzcCL filters.coffee controller in data-system
###
module.exports = class FilterManager

    ###*
     * Create a FilterManager.
     *
     * @param {String} cozyUrl - it's url
     * @param {String} auth - it's header authentication
     * @param {String} deviceName - it's device name
     * @param {PouchDB} db - the main PouchDB instance of the app.
    ###
    # constructor: (@cozyUrl, @auth, @deviceName, @db) ->
    constructor: (@config) ->
        @cozyUrl = @config.getCozyUrl()
        @auth = @config.get 'auth'
        @deviceName = @config.get 'deviceName'
        @db = @config.db

    ###*
     * Create or update a filter for a specific configuration.
     *
     * @param {Boolean} syncContacts - if you want contact synchronization
     * @param {Boolean} syncCalendars - if you want calendar synchronization
     * @param {Boolean} syncNotifs - if you want notification synchronization
     * @param {Function} callback - The callback that handles the response.
    ###
    # setFilter: (syncContacts, syncCalendars, syncNotifs, callback) ->
    setFilter: (callback) ->
        syncContacts = @config.get 'syncContacts'
        syncCalendars = @config.get 'syncCalendars'
        syncNotifs = @config.get 'cozyNotifications'

        log.info "setFilter syncContacts: #{syncContacts}, syncCalendars: " + \
                "#{syncCalendars}, syncNotifs: #{syncNotifs}"
        doc = @_getConfigFilter @config.attributes

        options = @_getOptions()
        options.body = doc

        # Add the filter in PouchDB
        filterId = @getFilterDocId()
        doc._id = filterId
        @db.get filterId, (err, existing) =>
            # assume err is 404, which means no doc yet.
            if existing?
                doc._rev = existing._rev

            @db.put doc, (err) ->
                return callback err if err

                # Delete rev before sending to Cozy
                delete doc._rev
                # Add filter in Cozy
                request.put options, (err, res, body) ->
                    if err or not (body?.success or body?._id)
                        err ?= body
                        return callback err

                    callback null, true


    _getFilterDocName: ->
        log.debug "getFilterDocId"
        "filter-#{@deviceName}-config"

    ###*
     * Get the design docId of the filter this device.
     *
     * @return {String}
    ###
    getFilterDocId: ->
        return "_design/#{@_getFilterDocName()}"

    ###*
     * Get filter name for this device.
     *
     * @return {String}
    ###
    getFilterName: ->
        log.info "getFilterName"

        "#{@_getFilterDocName()}/config"

    ###*
     * Get options to create a request.
     *
     * @return {Object}
    ###
    _getOptions: ->
        json: true
        auth: @auth
        url: "#{@cozyUrl}/ds-api/filters/config"


    ###*
     * Get configuration to create a filter
     *
     * @param {Boolean} syncContacts - if you want contact synchronization
     * @param {Boolean} syncCalendars - if you want calendar synchronization
     * @param {Boolean} syncNotifs - if you want notification synchronization
     *
     * @return {Object}
    ###
    _getConfigFilter: (options) ->
        # First check for docType
        compare = "doc.docType && ("
        compare += "doc.docType.toLowerCase() === 'file'"
        compare += " || doc.docType.toLowerCase() === 'folder'"
        if options.syncContacts
            compare += " || doc.docType.toLowerCase() === 'contact'"
        if options.syncCalendars
            compare += " || doc.docType.toLowerCase() === 'event'"
            compare += " || doc.docType.toLowerCase() === 'tag'"
        if options.cozyNotifications
            compare += " || (doc.docType.toLowerCase() === 'notification'"
            compare += " && doc.type === 'temporary')"

        compare += ")"

        # TODO ? add views attribute here, required by the DataSystem ?
        filters:
            config: "function (doc) { return #{compare}; }"
