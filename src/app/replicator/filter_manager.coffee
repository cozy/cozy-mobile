log = require('../lib/persistent_log')
    prefix: "Filter Manager"
    date: true

###*
 * Get configuration to create a filter
 *
 * @param {Boolean} syncContacts - if you want contact synchronization
 * @param {Boolean} syncCalendars - if you want calendar synchronization
 * @param {Boolean} syncNotifs - if you want notification synchronization
 *
 * @return {Object}
###
_getConfigFilter = (syncContacts, syncCalendars, syncNotifs) ->
    # First check for docType
    compare = "doc.docType && ("
    compare += "doc.docType.toLowerCase() === 'file'"
    compare += " || doc.docType.toLowerCase() === 'folder'"
    if syncContacts
        compare += " || doc.docType.toLowerCase() === 'contact'"
    if syncCalendars
        compare += " || doc.docType.toLowerCase() === 'event'"
        compare += " || doc.docType.toLowerCase() === 'tag'"
    if syncNotifs
        compare += " || doc.docType.toLowerCase() === 'notification'"

    compare += ")"

    # TODO ? add views attribute here, required by the DataSystem ?
    filters:
        config: "function (doc) { return #{compare}; }"

_getFilterDocName = ->
    log.debug "getFilterDocId"
    "filter-#{deviceName}-config"

deviceName = null

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
    constructor: (@config, @requestCozy, @db) ->
        deviceName = @config.get 'deviceName'

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

        doc = _getConfigFilter syncContacts, syncCalendars, syncNotifs

        # Add the filter in PouchDB
        filterId = @getFilterDocId()
        doc._id = filterId
        @db.get filterId, (err, existing) =>
            # assume err is 404, which means no doc yet.
            if existing?
                doc._rev = existing._rev

            @db.put doc, (err) =>
                return callback err if err

                # Delete rev before sending to Cozy
                delete doc._rev
                # Add filter in Cozy
                options =
                    method: 'put'
                    type: 'data-system'
                    path: '/filters/config'
                    body: doc
                @requestCozy.request options, (err, res, body) ->
                    if err or not (body?.success or body?._id)
                        err ?= body
                        return callback err

                    callback null, true

    filterRemoteExist: (callback = ->) ->
        log.debug "filterRemoteExist"

        options =
            method: 'get'
            type: 'data-system'
            path: '/filters/config'
        @requestCozy.request options, (err, res, body) =>
            if res?.status is 404
                console.info 'The above 404 is normal, we create the filter'
                return @setFilter callback
            callback()

    ###*
     * Get the design docId of the filter this device.
     *
     * @return {String}
    ###
    getFilterDocId: ->
        return "_design/#{_getFilterDocName()}"

    ###*
     * Get filter name for this device.
     *
     * @return {String}
    ###
    getFilterName: ->
        log.debug "getFilterName"

        "#{_getFilterDocName()}/config"
